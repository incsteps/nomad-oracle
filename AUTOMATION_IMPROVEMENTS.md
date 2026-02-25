# Automation Improvements Summary

## Overview
This document summarizes the automation improvements made to ensure the Nomad cluster with ACL and MinIO deploys automatically in a single `terraform apply` command.

## Changes Implemented

### 1. Configurable CPU and Memory Resources

#### New Variables Added
- `server_ocpus` - Number of OCPUs for server (default: 2)
- `server_memory_gb` - Memory in GB for server (default: 12)
- `client_ocpus` - Number of OCPUs for clients (default: 4)
- `client_memory_gb` - Memory in GB for clients (default: 12)

#### Files Modified
- `variables.tf` - Added CPU/memory variables
- `modules/nomad/variables.tf` - Added module-level variables
- `modules/nomad/main.tf` - Updated `shape_config` to use variables
- `cluster.tf` - Pass variables to Nomad module
- `terraform.tfvars` - Set default values

**Benefits:**
- Easy to adjust resources per environment
- Consistent resource allocation
- Better cost management

### 2. Automated ACL Token Creation

#### Server Cloud-Init Enhancement
Updated `modules/nomad/cloud-init-server.yaml` to automatically:

1. **Bootstrap Nomad ACL** - Creates management token
2. **Create Node Policy** - Policy for client registration
3. **Generate Client Token** - Token for clients to register

**Tokens Saved To:**
- `/etc/nomad.d/secrets/nomad-token.env` - Management token
- `/etc/nomad.d/secrets/bootstrap-token.json` - Full bootstrap response
- `/etc/nomad.d/secrets/client-token.txt` - Client registration token
- `/etc/nomad.d/secrets/client-token.json` - Full client token response
- `/etc/nomad.d/secrets/node-policy.hcl` - Node registration policy

### 3. Client Token Auto-Configuration

#### Client SystemD Service Updated
`modules/nomad/cloud-init-client.yaml` now includes:

```ini
[Service]
EnvironmentFile=-/etc/nomad.d/secrets/client-token.env
ExecStartPre=/bin/bash -c 'if [ -f /etc/nomad.d/secrets/client-token.txt ]; then echo "NOMAD_TOKEN=$(cat /etc/nomad.d/secrets/client-token.txt)" > /etc/nomad.d/secrets/client-token.env; fi'
```

**Note:** Clients still need token distribution via the helper script (see below).

### 4. Automated MinIO Deployment via Nomad Provider

#### New Files Created
- `versions.tf` - Terraform and provider version requirements
- `nomad-bootstrap.tf` - Token retrieval and MinIO deployment logic

#### Deployment Flow
```
Terraform Apply
    ↓
Create Infrastructure (VCN, Server, Client)
    ↓
Wait 5 minutes (null_resource)
    ↓
Fetch Bootstrap Token (data.external)
    ↓
Configure Nomad Provider
    ↓
Deploy MinIO Job (nomad_job resource)
    ↓
Complete!
```

#### MinIO Configuration
- **Resources**: 2 CPU cores, 4 GB RAM (increased from 1 CPU/2GB)
- **Storage**: `/mnt/minio-data` on 1TB server boot volume
- **Ports**: 9000 (API), 9001 (Console)
- **Node Constraint**: Runs only on `nomad-server-1`
- **Credentials**: Loaded from `/etc/nomad.d/secrets/minio.env`

### 5. Enhanced Terraform Outputs

#### New Outputs Added
```hcl
nomad_bootstrap_token  # Management token (sensitive)
nomad_client_token     # Client registration token (sensitive)
minio_endpoint         # http://SERVER_IP:9000
minio_console          # http://SERVER_IP:9001
minio_credentials      # {username, password} (sensitive)
```

**View Sensitive Outputs:**
```bash
terraform output nomad_bootstrap_token
terraform output nomad_client_token
terraform output minio_credentials
```

### 6. Helper Scripts

#### configure-client-tokens.sh
Script to manually distribute client tokens if needed:

```bash
./scripts/configure-client-tokens.sh <server_ip> <client_ip_1> [client_ip_2] ...
```

**Use Case:** If clients are added after initial deployment or tokens need redistribution.

## Deployment Process

### Single Command Deployment
```bash
TF_VAR_region=af-johannesburg-1 terraform apply -auto-approve
```

**What Happens:**
1. Creates OCI infrastructure (VCN, instances, storage, security groups)
2. Waits 5 minutes for cloud-init to complete
3. Fetches Nomad ACL tokens from server
4. Configures Nomad provider with bootstrap token
5. Deploys MinIO job to Nomad cluster
6. Outputs all endpoints and tokens

**Total Time:** ~8-10 minutes
- Infrastructure creation: 3-4 minutes
- Cloud-init & ACL bootstrap: 5 minutes
- MinIO deployment: 30 seconds

### Post-Deployment Steps

#### 1. Configure Local Nomad CLI
```bash
# Get bootstrap token
export NOMAD_TOKEN=$(terraform output -raw nomad_bootstrap_token)
export NOMAD_ADDR=$(terraform output -raw nomad_url)

# Save to shell profile (fish)
set -Ux NOMAD_TOKEN $(terraform output -raw nomad_bootstrap_token)
set -Ux NOMAD_ADDR $(terraform output -raw nomad_url)
```

#### 2. Configure Client Tokens (If Needed)
```bash
# Get IPs from outputs
SERVER_IP=$(terraform output -raw nomad_server_public_ip)
CLIENT_IPS=$(terraform output -json nomad_clients_ips | jq -r '.[]')

# Run configuration script
./scripts/configure-client-tokens.sh $SERVER_IP $CLIENT_IPS
```

#### 3. Verify Deployment
```bash
# Check cluster status
nomad status

# Check nodes
nomad node status

# Check MinIO job
nomad job status minio

# Access MinIO console
# http://<server-ip>:9001
# Username: $(terraform output -json minio_credentials | jq -r '.username')
# Password: $(terraform output -json minio_credentials | jq -r '.password')
```

#### 4. Create MinIO Buckets
```bash
# Install MinIO client
brew install minio/stable/mc

# Configure alias
MINIO_USER=$(terraform output -json minio_credentials | jq -r '.username')
MINIO_PASS=$(terraform output -json minio_credentials | jq -r '.password')
SERVER_IP=$(terraform output -raw nomad_server_public_ip)

mc alias set nomad-minio http://$SERVER_IP:9000 $MINIO_USER $MINIO_PASS

# Create buckets
mc mb nomad-minio/nextflow-work
mc mb nomad-minio/nextflow-results

# List buckets
mc ls nomad-minio
```

## Configuration Examples

### terraform.tfvars
```hcl
# Region and Project
region       = "af-johannesburg-1"
project_name = "nomadjhb"

# Network Configuration
vcn_cidr_block            = "10.0.0.0/16"
public_subnet_cidr_block  = "10.0.1.0/24"
private_subnet_cidr_block = "10.0.2.0/24"
ssh_source_cidr           = "YOUR_IP/32"

# Nomad Configuration
nomad_server_count = 1
nomad_client_count = 1

# Storage Configuration
server_boot_volume_size_gb = 1000  # 1TB for MinIO
client_boot_volume_size_gb = 200

# Server Resources
server_ocpus     = 2
server_memory_gb = 12

# Client Resources
client_ocpus     = 4
client_memory_gb = 12

# MinIO Credentials (from minio-secrets.env)
minio_root_user     = "generated-username"
minio_root_password = "generated-password"
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  Single terraform apply                 │
└─────────────────────────────────────────────────────────┘
                           ↓
    ┌─────────────────────────────────────────────┐
    │         OCI Infrastructure Created          │
    │                                             │
    │  ┌─────────────┐         ┌──────────────┐  │
    │  │   Server    │         │   Client     │  │
    │  │  (ARM/1TB)  │ ←──────→│   (x86)      │  │
    │  │  2CPU/12GB  │         │  4CPU/12GB   │  │
    │  └─────────────┘         └──────────────┘  │
    └─────────────────────────────────────────────┘
                           ↓
    ┌─────────────────────────────────────────────┐
    │         Cloud-Init Runs (5 minutes)         │
    │                                             │
    │  • Install Docker & Nomad                   │
    │  • Bootstrap ACL                            │
    │  • Create Management Token                  │
    │  • Create Node Policy                       │
    │  • Create Client Token                      │
    │  • Store MinIO Credentials                  │
    └─────────────────────────────────────────────┘
                           ↓
    ┌─────────────────────────────────────────────┐
    │    Terraform Fetches Tokens from Server     │
    │                                             │
    │  • SSH to server                            │
    │  • Read /etc/nomad.d/secrets/*              │
    │  • Configure Nomad Provider                 │
    └─────────────────────────────────────────────┘
                           ↓
    ┌─────────────────────────────────────────────┐
    │       MinIO Deployed via Nomad Provider     │
    │                                             │
    │  • nomad_job resource                       │
    │  • Constraint: server node only             │
    │  • Resources: 2 CPU / 4 GB RAM              │
    │  • Storage: /mnt/minio-data (1TB)           │
    └─────────────────────────────────────────────┘
                           ↓
    ┌─────────────────────────────────────────────┐
    │            Cluster Ready to Use!            │
    │                                             │
    │  • Nomad UI: http://server:4646             │
    │  • MinIO Console: http://server:9001        │
    │  • All tokens available in outputs          │
    └─────────────────────────────────────────────┘
```

## Benefits

### Before Improvements
1. ❌ Manual CPU/memory configuration in code
2. ❌ Manual ACL bootstrap
3. ❌ Manual client token creation
4. ❌ Manual client configuration
5. ❌ Manual MinIO deployment
6. ❌ Multiple manual steps after `terraform apply`

### After Improvements
1. ✅ Configurable CPU/memory via variables
2. ✅ Automatic ACL bootstrap
3. ✅ Automatic token creation
4. ✅ Semi-automatic client configuration (helper script)
5. ✅ Automatic MinIO deployment
6. ✅ Single `terraform apply` command

## Known Limitations

### 1. Client Token Distribution
- Clients need token fetched from server
- Helper script required: `configure-client-tokens.sh`
- **Reason**: No shared storage; SSH required to fetch token

**Workaround:** Use the provided script after initial deployment

### 2. Bootstrap Wait Time
- Hard-coded 5-minute wait
- May be too long for fast systems, too short for slow ones

**Improvement Idea:** Implement polling with timeout instead of fixed sleep

### 3. SSH Key Dependency
- Requires `~/.ssh/id_ed25519` to exist
- Path is hard-coded in scripts

**Workaround:** Update scripts to use `SSH_KEY` environment variable

### 4. Token in Terraform State
- Bootstrap tokens stored in Terraform state
- State file contains sensitive data

**Mitigation:**
- Use remote state with encryption (S3, Terraform Cloud)
- Restrict state file permissions
- Consider Vault integration for production

## Troubleshooting

### MinIO Deployment Fails
**Symptom:** `nomad_job.minio` fails with permission denied

**Solution:**
```bash
# Verify token retrieval worked
terraform output nomad_bootstrap_token

# Check Nomad is accessible
curl http://$(terraform output -raw nomad_server_public_ip):4646/v1/status/leader

# Manually deploy
export NOMAD_TOKEN=$(terraform output -raw nomad_bootstrap_token)
export NOMAD_ADDR=$(terraform output -raw nomad_url)
nomad job run nomad-jobs/minio.nomad
```

### Client Not Registering
**Symptom:** `nomad node status` shows no clients

**Solution:**
```bash
# Run token configuration script
SERVER_IP=$(terraform output -raw nomad_server_public_ip)
CLIENT_IP=$(terraform output -json nomad_clients_ips | jq -r '.[0]')

./scripts/configure-client-tokens.sh $SERVER_IP $CLIENT_IP
```

### Token Retrieval Times Out
**Symptom:** Terraform hangs during token fetch

**Solution:**
```bash
# SSH to server manually
ssh -i ~/.ssh/id_ed25519 ubuntu@$(terraform output -raw nomad_server_public_ip)

# Check cloud-init status
cloud-init status

# Check if tokens exist
sudo ls -la /etc/nomad.d/secrets/

# If tokens missing, check logs
sudo tail -100 /var/log/cloud-init-output.log
```

## Future Improvements

1. **Vault Integration**: Store tokens in HashiCorp Vault instead of Terraform state
2. **Polling vs. Sleep**: Replace fixed 5-minute wait with intelligent polling
3. **Multi-Region Support**: Extend to deploy across multiple OCI regions
4. **MinIO High Availability**: Support distributed MinIO (4+ nodes)
5. **Automated Testing**: Add Terratest or similar for validation
6. **Monitoring Integration**: Auto-deploy Prometheus/Grafana for observability

---

**Last Updated:** February 24, 2026  
**Terraform Version:** >= 1.0  
**Nomad Provider Version:** ~> 2.0
