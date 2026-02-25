# Security Implementation: ACL and Secrets Management

## Summary

This document summarizes the security enhancements implemented for the Nomad cluster, including ACL (Access Control Lists) and automated secrets management for both Nomad and MinIO.

## Changes Implemented

### 1. Nomad ACL Configuration

#### Server Configuration (`modules/nomad/cloud-init-server.yaml`)

Added ACL configuration block:
```hcl
acl {
  enabled = true
}
```

Added automated bootstrap process:
- Waits for Nomad to be ready (up to 60 seconds)
- Runs `nomad acl bootstrap` to generate management token
- Saves full bootstrap response to `/etc/nomad.d/secrets/bootstrap-token.json`
- Extracts and saves management token to `/etc/nomad.d/secrets/nomad-token.env`

#### Client Configuration (`modules/nomad/cloud-init-client.yaml`)

Added ACL configuration block:
```hcl
acl {
  enabled = true
}
```

Clients automatically authenticate with the server using the ACL system.

### 2. MinIO Credential Management

#### Credential Generation Script (`scripts/generate-minio-secrets.sh`)

Generates secure random credentials:
- **MINIO_ROOT_USER**: 12-character alphanumeric string
- **MINIO_ROOT_PASSWORD**: 32-character strong password
- Saves to `minio-secrets.env` with 600 permissions

#### Terraform Variables

Added sensitive variables in `variables.tf`:
```hcl
variable "minio_root_user" {
  type        = string
  description = "MinIO root username"
  sensitive   = true
}

variable "minio_root_password" {
  type        = string
  description = "MinIO root password"
  sensitive   = true
}
```

#### Cloud-Init Integration

Modified `modules/nomad/cloud-init-server.yaml` to:
- Create `/etc/nomad.d/secrets/` directory with 700 permissions
- Write MinIO credentials to `/etc/nomad.d/secrets/minio.env` with 600 permissions
- Credentials are passed from Terraform variables via cloud-init template

#### MinIO Nomad Job (`nomad-jobs/minio.nomad`)

Updated to use Nomad's template stanza:
```hcl
template {
  data = <<EOH
{{ with file "/etc/nomad.d/secrets/minio.env" -}}
{{ . }}
{{- end }}
EOH
  destination = "secrets/minio.env"
  env         = true
}
```

This reads credentials from the host file and injects them as environment variables into the MinIO container.

### 3. Security Architecture

#### Credential Flow

```
Local Machine
    ↓ (generate-minio-secrets.sh)
minio-secrets.env
    ↓ (manual: copy to terraform.tfvars)
Terraform Variables
    ↓ (terraform apply)
Cloud-Init Template
    ↓ (writes to server)
/etc/nomad.d/secrets/minio.env (mode: 600)
    ↓ (Nomad template reads)
MinIO Container Environment
```

#### ACL Token Flow

```
Nomad Server Starts
    ↓ (cloud-init script)
nomad acl bootstrap
    ↓ (saves JSON)
/etc/nomad.d/secrets/bootstrap-token.json
    ↓ (extracts SecretID)
/etc/nomad.d/secrets/nomad-token.env
    ↓ (user retrieves)
Local Environment Variables
    ↓ (NOMAD_TOKEN)
Nomad CLI/API Requests
```

### 4. File Structure

```
oci-vm-nomad/
├── scripts/
│   ├── generate-minio-secrets.sh    # Generate MinIO credentials
│   └── quick-start.sh               # Automated deployment script
├── acl-policies/
│   ├── readonly-policy.hcl          # Read-only access policy
│   ├── developer-policy.hcl         # Developer access policy
│   └── cicd-policy.hcl              # CI/CD automation policy
├── nomad-jobs/
│   └── minio.nomad                  # MinIO job with template secrets
├── minio-secrets.env                # Generated credentials (gitignored)
├── nomad-token.env                  # Retrieved ACL token (gitignored)
├── DEPLOYMENT_GUIDE.md              # Comprehensive deployment guide
└── SECURITY_IMPLEMENTATION.md       # This file
```

### 5. Security Measures

#### Secrets Protection

1. **File Permissions**:
   - `minio-secrets.env`: 600 (owner read/write only)
   - `nomad-token.env`: 600 (owner read/write only)
   - `/etc/nomad.d/secrets/*`: 600 (root read/write only)

2. **Git Exclusion** (`.gitignore`):
   ```
   minio-secrets.env
   nomad-token.env
   **/*secrets*.env
   **/*token*.env
   **/*.tfvars
   ```

3. **Terraform Sensitive Variables**:
   - Marked as `sensitive = true`
   - Not displayed in plan/apply output
   - Not stored in state file in plain text

#### Access Control

1. **Nomad API**:
   - All endpoints require valid ACL token
   - Anonymous access: DENIED
   - Token via `NOMAD_TOKEN` environment variable or HTTP header

2. **MinIO**:
   - Ports 9000, 9001 restricted to whitelisted IP (`ssh_source_cidr`)
   - Strong randomly-generated credentials
   - No default credentials (minioadmin removed)

3. **Network Security**:
   - Server SSH: whitelisted IP only
   - Nomad API: whitelisted IP only
   - MinIO API/Console: whitelisted IP only
   - Clients: private subnet, no public access

### 6. ACL Policy Examples

Created three policy templates:

#### Read-Only Policy
- List and read jobs
- Read node/agent/quota information
- No write permissions
- Use case: Monitoring, auditing

#### Developer Policy
- Full job lifecycle management
- Execute commands in allocations
- Read logs and filesystem
- Write host volumes
- Use case: Development teams

#### CI/CD Policy
- Submit and manage jobs
- Read logs for verification
- Read cluster state
- Use case: Automated deployments

### 7. Usage Examples

#### Deploy with ACL

```bash
# Generate MinIO credentials
./scripts/generate-minio-secrets.sh

# Update terraform.tfvars with credentials
# Then deploy
terraform apply

# Retrieve Nomad token
ssh ubuntu@<server-ip> "sudo cat /etc/nomad.d/secrets/nomad-token.env"

# Use Nomad CLI
export NOMAD_TOKEN=<token>
nomad status
```

#### Deploy MinIO

```bash
# Credentials are automatically loaded from host file
nomad job run nomad-jobs/minio.nomad

# Verify
nomad job status minio
```

#### Create Additional Tokens

```bash
# Apply a policy
nomad acl policy apply -description "Read Only" readonly acl-policies/readonly-policy.hcl

# Create a token
nomad acl token create -name="Monitor Token" -policy=readonly

# Use the new token
export NOMAD_TOKEN=<new-token>
nomad status  # Will have read-only access
```

## Migration from Non-ACL Cluster

If you have an existing cluster without ACL:

1. **Backup current state**:
   ```bash
   nomad operator snapshot save backup.snap
   ```

2. **Update Terraform code** with changes from this implementation

3. **Destroy and recreate** (ACL cannot be enabled on running cluster):
   ```bash
   terraform destroy
   terraform apply
   ```

4. **Retrieve new bootstrap token**

5. **Update all client scripts** to use `NOMAD_TOKEN`

6. **Re-deploy jobs** using authenticated CLI

## Security Best Practices

### For Production

1. **Rotate Credentials Regularly**:
   - Generate new MinIO credentials monthly
   - Create new Nomad tokens for specific purposes
   - Revoke old tokens

2. **Use Least Privilege**:
   - Don't use management token for day-to-day operations
   - Create specific tokens for each use case
   - Use policy-based access control

3. **Enable TLS**:
   - Configure HTTPS for Nomad API
   - Configure HTTPS for MinIO
   - Use valid certificates

4. **Monitor Access**:
   - Review Nomad audit logs
   - Track token usage
   - Monitor failed authentication attempts

5. **Backup Tokens Securely**:
   - Store bootstrap token in secure vault (1Password, AWS Secrets Manager)
   - Never commit tokens to version control
   - Limit token distribution

### For Development

1. **Use Separate Credentials**:
   - Development cluster: different credentials
   - Production cluster: different credentials
   - Never reuse

2. **Token Expiration**:
   - Create time-limited tokens for testing
   - Automatically revoke old tokens

3. **IP Whitelisting**:
   - Update `ssh_source_cidr` when IP changes
   - Use VPN for consistent access

## Troubleshooting

### "Permission denied" errors

**Cause**: No ACL token set

**Solution**:
```bash
export NOMAD_TOKEN=<your-token>
```

### MinIO job fails to start

**Cause**: Cannot read `/etc/nomad.d/secrets/minio.env`

**Solution**:
```bash
ssh ubuntu@<server-ip>
sudo chmod 644 /etc/nomad.d/secrets/minio.env
```

### ACL bootstrap didn't run

**Cause**: Nomad wasn't ready in time

**Solution**:
```bash
ssh ubuntu@<server-ip>
sudo nomad acl bootstrap -json | sudo tee /etc/nomad.d/secrets/bootstrap-token.json
```

### Lost bootstrap token

**Cause**: Token file deleted or lost

**Solution**:
1. If you have a valid management token, you can create new ones
2. If completely lost, you must destroy and recreate the cluster
3. Always backup the bootstrap token immediately after deployment

## References

- [Nomad ACL System](https://developer.hashicorp.com/nomad/docs/configuration/acl)
- [Nomad ACL Bootstrap](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-bootstrap)
- [Nomad Template Stanza](https://developer.hashicorp.com/nomad/docs/job-specification/template)
- [MinIO Security](https://min.io/docs/minio/linux/operations/security.html)
- [OCI Security Best Practices](https://docs.oracle.com/en-us/iaas/Content/Security/Concepts/security_guide.htm)

## Change Log

- **2026-02-24**: Initial implementation
  - Enabled Nomad ACL on server and clients
  - Added automated ACL bootstrap
  - Implemented MinIO credential management
  - Created secret generation scripts
  - Added ACL policy examples
  - Updated documentation
