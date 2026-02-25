# Deployment Guide: Secure Nomad Cluster with ACL and MinIO

This guide covers deploying a secure Nomad cluster with ACL enabled and MinIO using credential management.

## Overview

The infrastructure includes:
- **Nomad Server** with ACL enabled (requires tokens for all requests)
- **Nomad Clients** registered with ACL-enabled server
- **MinIO** deployed via Nomad with secure credential management
- **Automated secret generation** for both Nomad and MinIO

## Prerequisites

- OCI account and credentials configured
- Terraform installed (>= 1.0)
- SSH key pair (`~/.ssh/id_ed25519`)
- OpenSSL (for generating secrets)

## Step 1: Generate MinIO Credentials

Generate secure random credentials for MinIO:

```bash
cd /Users/abhi/projects/PHD-pub-nf-nomad/analysis/infrastructure/03_automation/035_terraform/oci-vm-nomad

# Generate credentials
./scripts/generate-minio-secrets.sh

# This creates minio-secrets.env with:
# - MINIO_ROOT_USER (12 char random string)
# - MINIO_ROOT_PASSWORD (32 char random string)
```

The credentials are saved to `minio-secrets.env` with 600 permissions.

## Step 2: Configure Terraform Variables

Update `terraform.tfvars` with the generated MinIO credentials:

```hcl
# Region and Project
region       = "af-johannesburg-1"
project_name = "nomadjhb"

# Compartment (your OCI compartment OCID)
compartment_ocid = "ocid1.compartment.oc1..xxxxx"
tenancy_ocid     = "ocid1.tenancy.oc1..xxxxx"

# Network Configuration
vcn_cidr_block            = "10.0.0.0/16"
public_subnet_cidr_block  = "10.0.1.0/24"
private_subnet_cidr_block = "10.0.2.0/24"
ssh_source_cidr           = "146.232.174.192/32"  # Your IP

# SSH Key
ssh_public_key_content = "ssh-ed25519 AAAAC3...your-key..."

# Nomad Configuration
nomad_server_count = 1
nomad_client_count = 1

# Storage
object_storage_bucket_name = "nomad-jhb-storage"

# MinIO Credentials (from minio-secrets.env)
minio_root_user     = "xxxxxxxxxxxx"  # Copy from minio-secrets.env
minio_root_password = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # Copy from minio-secrets.env
```

**Security Note**: The `terraform.tfvars` file is in `.gitignore` and won't be committed.

## Step 3: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
TF_VAR_region=af-johannesburg-1 terraform plan

# Deploy
TF_VAR_region=af-johannesburg-1 terraform apply -auto-approve
```

## Step 4: Retrieve Nomad ACL Bootstrap Token

After deployment, the Nomad server automatically bootstraps the ACL system and saves the management token.

SSH to the server and retrieve it:

```bash
# Get server IP from Terraform output
export NOMAD_SERVER_IP=$(terraform output -raw nomad_server_public_ip)

# SSH to server
ssh -i ~/.ssh/id_ed25519 ubuntu@$NOMAD_SERVER_IP

# On the server, retrieve the token
sudo cat /etc/nomad.d/secrets/nomad-token.env
```

Output will be:
```bash
NOMAD_TOKEN=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
NOMAD_ADDR=http://127.0.0.1:4646
```

**Save this token securely** - you'll need it for all Nomad operations.

## Step 5: Configure Local Nomad CLI

On your local machine, configure the Nomad CLI to use the token:

```bash
# Set environment variables
export NOMAD_ADDR=http://<NOMAD_SERVER_PUBLIC_IP>:4646
export NOMAD_TOKEN=<TOKEN_FROM_STEP_4>

# Test authentication
nomad status

# Save to your shell profile (fish)
echo "set -gx NOMAD_ADDR http://<NOMAD_SERVER_PUBLIC_IP>:4646" >> ~/.config/fish/config.fish
echo "set -gx NOMAD_TOKEN <TOKEN_FROM_STEP_4>" >> ~/.config/fish/config.fish
```

For bash/zsh:
```bash
echo "export NOMAD_ADDR=http://<NOMAD_SERVER_PUBLIC_IP>:4646" >> ~/.bashrc
echo "export NOMAD_TOKEN=<TOKEN_FROM_STEP_4>" >> ~/.bashrc
```

## Step 6: Prepare MinIO Data Directory

SSH to the server and create the data directory:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@$NOMAD_SERVER_IP

# Create MinIO data directory
sudo mkdir -p /mnt/minio-data
sudo chown -R 1000:1000 /mnt/minio-data
sudo chmod -R 755 /mnt/minio-data

# Exit SSH
exit
```

## Step 7: Deploy MinIO to Nomad

With ACL enabled, you need the token to deploy jobs:

```bash
# Ensure NOMAD_TOKEN is set
export NOMAD_TOKEN=<YOUR_MANAGEMENT_TOKEN>

# Deploy MinIO
nomad job run nomad-jobs/minio.nomad

# Check status
nomad job status minio

# View allocation details
nomad alloc status $(nomad job status minio | grep running | awk '{print $1}' | head -1)
```

## Step 8: Verify MinIO Deployment

```bash
# Check MinIO health
curl http://$NOMAD_SERVER_IP:9000/minio/health/live

# Access MinIO Console
# Open browser: http://<NOMAD_SERVER_IP>:9001
# Login with credentials from minio-secrets.env
```

## Step 9: Configure MinIO Client

```bash
# Install MinIO client
wget https://dl.min.io/client/mc/release/darwin-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure mc alias
source minio-secrets.env
mc alias set nomad-minio http://$NOMAD_SERVER_IP:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD

# Create buckets for Nextflow
mc mb nomad-minio/nextflow-work
mc mb nomad-minio/nextflow-results

# List buckets
mc ls nomad-minio
```

## Step 10: Update Nextflow Configuration

The MinIO credentials are automatically available on the Nomad server at `/etc/nomad.d/secrets/minio.env`.

Update your Nextflow config:

```groovy
// nextflow/nextflow.minio.config
aws {
    accessKey = '<MINIO_ROOT_USER>'
    secretKey = '<MINIO_ROOT_PASSWORD>'
    client {
        endpoint = 'http://92.4.139.74:9000'
        s3PathStyleAccess = true
    }
}

workDir = 's3://nextflow-work'

process {
    executor = 'nomad'
    
    // Nomad executor needs ACL token
    nomad {
        client {
            address = 'http://92.4.139.74:4646'
            token = '<NOMAD_TOKEN>'
        }
    }
}
```

## Security Architecture

### Nomad ACL

```
┌─────────────────────────────────────────────┐
│           Nomad ACL Security Model          │
├─────────────────────────────────────────────┤
│                                             │
│  1. Bootstrap Token (Management)            │
│     └─> Full admin access                   │
│     └─> Stored: /etc/nomad.d/secrets/       │
│                                             │
│  2. Client Requests                         │
│     └─> Require NOMAD_TOKEN env var         │
│     └─> Anonymous access: DENIED            │
│                                             │
│  3. API Endpoints                           │
│     └─> All require authentication          │
│     └─> Token via HTTP header or env        │
│                                             │
└─────────────────────────────────────────────┘
```

### MinIO Credentials Flow

```
┌──────────────┐     1. Generated by script
│   Local      │     ┌────────────────────────┐
│   Machine    │────>│  minio-secrets.env     │
│              │     │  - MINIO_ROOT_USER     │
└──────────────┘     │  - MINIO_ROOT_PASSWORD │
                     └────────────────────────┘
                              │
                              │ 2. Via Terraform variables
                              ▼
                     ┌────────────────────────┐
                     │    Terraform Apply     │
                     └────────────────────────┘
                              │
                              │ 3. Cloud-init writes to server
                              ▼
                     ┌────────────────────────┐
                     │  /etc/nomad.d/secrets/ │
                     │     minio.env          │
                     │  (mode: 600)           │
                     └────────────────────────┘
                              │
                              │ 4. Nomad template reads
                              ▼
                     ┌────────────────────────┐
                     │   MinIO Container      │
                     │   Environment Vars     │
                     └────────────────────────┘
```

## Credential Storage Locations

### On Nomad Server

```
/etc/nomad.d/secrets/
├── bootstrap-token.json          # Full ACL bootstrap response
├── nomad-token.env              # Extracted management token
└── minio.env                    # MinIO credentials

Permissions: 600 (owner read/write only)
```

### On Local Machine

```
oci-vm-nomad/
├── minio-secrets.env            # Generated MinIO credentials
└── terraform.tfvars             # All sensitive config

Both files in .gitignore
```

## Common Operations

### Create Additional ACL Tokens

```bash
# Create a token for CI/CD
nomad acl policy apply -description "CI/CD Policy" ci-policy ci-policy.hcl
nomad acl token create -name="CI Token" -policy=ci-policy

# Create a read-only token
nomad acl policy apply -description "Read Only" readonly readonly-policy.hcl
nomad acl token create -name="Read Only Token" -policy=readonly
```

### Rotate MinIO Credentials

```bash
# 1. Generate new credentials
./scripts/generate-minio-secrets.sh

# 2. Update terraform.tfvars with new credentials

# 3. Apply changes (will update cloud-init, requires server recreation)
TF_VAR_region=af-johannesburg-1 terraform apply

# 4. Re-deploy MinIO job (picks up new credentials)
nomad job run nomad-jobs/minio.nomad
```

### View Nomad Logs

```bash
# On server
ssh -i ~/.ssh/id_ed25519 ubuntu@$NOMAD_SERVER_IP

# View Nomad service logs
sudo journalctl -u nomad.service -f

# View cloud-init logs (for troubleshooting bootstrap)
sudo cat /var/log/cloud-init-output.log
```

## Troubleshooting

### "Permission denied" when running Nomad commands

**Issue**: ACL is enabled but no token is set.

**Solution**:
```bash
# Retrieve token from server
ssh ubuntu@$NOMAD_SERVER_IP "sudo cat /etc/nomad.d/secrets/nomad-token.env"

# Set locally
export NOMAD_TOKEN=<token>
```

### MinIO deployment fails with "permission denied"

**Issue**: Template can't read `/etc/nomad.d/secrets/minio.env`

**Solution**:
```bash
# SSH to server and check permissions
ssh ubuntu@$NOMAD_SERVER_IP
sudo ls -la /etc/nomad.d/secrets/
sudo chmod 644 /etc/nomad.d/secrets/minio.env  # Make readable by Nomad
```

### ACL bootstrap didn't run

**Issue**: Bootstrap script timed out or Nomad wasn't ready.

**Solution**:
```bash
# SSH to server
ssh ubuntu@$NOMAD_SERVER_IP

# Manually bootstrap
sudo nomad acl bootstrap -json | sudo tee /etc/nomad.d/secrets/bootstrap-token.json
MGMT_TOKEN=$(sudo jq -r '.SecretID' /etc/nomad.d/secrets/bootstrap-token.json)
echo "export NOMAD_TOKEN=$MGMT_TOKEN" | sudo tee /etc/nomad.d/secrets/nomad-token.env
```

### Can't access MinIO console from browser

**Issue**: Security group rules not applied or IP mismatch.

**Solution**:
```bash
# Check your current IP
curl ifconfig.me

# Update terraform.tfvars with correct IP
ssh_source_cidr = "<YOUR_IP>/32"

# Re-apply Terraform
TF_VAR_region=af-johannesburg-1 terraform apply
```

## Best Practices

### Security

1. **Never commit secrets**: `terraform.tfvars` and `minio-secrets.env` are in `.gitignore`
2. **Rotate tokens regularly**: Create new management tokens and revoke old ones
3. **Use least privilege**: Create specific ACL policies for different use cases
4. **Enable TLS in production**: Configure HTTPS for both Nomad and MinIO
5. **Backup tokens**: Store management token in a secure vault (1Password, LastPass, etc.)

### Operations

1. **Monitor ACL usage**: `nomad acl token list` to see active tokens
2. **Audit logs**: Review Nomad audit logs regularly
3. **Backup secrets directory**: `/etc/nomad.d/secrets/` contains critical credentials
4. **Document token purposes**: Keep track of which tokens are used where

## Next Steps

1. ✅ Deploy secure Nomad cluster with ACL
2. ✅ Deploy MinIO with credential management
3. 🔄 Create ACL policies for different use cases
4. 🔄 Set up automated backups for MinIO data
5. 🔄 Configure TLS/HTTPS for production
6. 🔄 Integrate with Nextflow

## References

- [Nomad ACL Documentation](https://developer.hashicorp.com/nomad/docs/configuration/acl)
- [Nomad ACL Bootstrap](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-bootstrap)
- [Nomad Template Stanza](https://developer.hashicorp.com/nomad/docs/job-specification/template)
- [MinIO Docker Deployment](https://min.io/docs/minio/linux/operations/installation.html)
