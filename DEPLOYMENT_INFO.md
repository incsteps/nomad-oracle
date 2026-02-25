# Deployment Information

## Deployment Date
**February 24, 2026 - 13:16 UTC**

## Infrastructure Details

### Nomad Cluster
- **Server Public IP**: 84.8.137.209
- **Server Private IP**: 10.0.1.125
- **Client Private IP**: 10.0.2.122
- **Nomad UI**: http://84.8.137.209:4646

### OCI Object Storage
- **Bucket Name**: nomad-jhb-storage
- **Namespace**: frvf3pq2ql1y
- **Region**: af-johannesburg-1

## Security Configuration

### Nomad ACL
- **Status**: ✅ Enabled
- **Bootstrap Token**: d2670cb0-f4f5-e375-3b0d-ac44419ba635
- **Token Type**: Management (full access)
- **Client Node Token**: 22104c67-67f1-ba9e-904d-33fd0c543db5
- **Client Node ID**: 802656a1-1d2c-2089-10e8-f0f057622b57

#### Using the Token

On your local machine:
```bash
# Source the token file
source nomad-token.env

# Or set manually
export NOMAD_ADDR=http://84.8.137.209:4646
export NOMAD_TOKEN=d2670cb0-f4f5-e375-3b0d-ac44419ba635

# Test authentication
nomad status
nomad node status
```

#### Token Storage Locations
- **On Server**: `/etc/nomad.d/secrets/nomad-token.env` (mode: 600)
- **Locally**: `nomad-token.env` (mode: 600)

### MinIO Credentials
- **Username**: TUIe4l4qklLa
- **Password**: KoEjVCovFTTJpfdaoI6PDzkY5H3cvzNV

#### Credential Storage Locations
- **On Server**: `/etc/nomad.d/secrets/minio.env` (mode: 600)
- **Locally**: `minio-secrets.env` (mode: 600)

## Accessing Services

### SSH Access

#### Server (Direct)
```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@84.8.137.209
```

#### Client (via Server Jump Host)
```bash
# Method 1: Direct jump
ssh -i ~/.ssh/id_ed25519 -J ubuntu@84.8.137.209 ubuntu@10.0.2.122

# Method 2: Add to ~/.ssh/config
Host nomad-server
  HostName 84.8.137.209
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519

Host nomad-client
  HostName 10.0.2.122
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519
  ProxyJump nomad-server

# Then simply:
ssh nomad-server
ssh nomad-client
```

### Nomad UI
- **URL**: http://84.8.137.209:4646
- **Authentication**: Enter token when prompted
- **Token**: d2670cb0-f4f5-e375-3b0d-ac44419ba635

### MinIO (Once Deployed)
- **API Endpoint**: http://84.8.137.209:9000
- **Console**: http://84.8.137.209:9001
- **Username**: TUIe4l4qklLa
- **Password**: KoEjVCovFTTJpfdaoI6PDzkY5H3cvzNV

## Next Steps

### 1. Prepare MinIO Data Directory
```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@84.8.137.209

# Create MinIO data directory
sudo mkdir -p /mnt/minio-data
sudo chown -R 1000:1000 /mnt/minio-data
sudo chmod -R 755 /mnt/minio-data

# Exit
exit
```

### 2. Deploy MinIO
```bash
# Set Nomad environment
source nomad-token.env

# Deploy MinIO job
nomad job run nomad-jobs/minio.nomad

# Check status
nomad job status minio
```

### 3. Configure MinIO Client
```bash
# Install MinIO client (if not already installed)
# macOS:
brew install minio/stable/mc

# Configure alias
source minio-secrets.env
mc alias set nomad-minio http://84.8.137.209:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD

# Create buckets
mc mb nomad-minio/nextflow-work
mc mb nomad-minio/nextflow-results

# List buckets
mc ls nomad-minio
```

### 4. Test Nextflow
```bash
# Update nextflow/nextflow.minio.config with:
# - MinIO endpoint: http://84.8.137.209:9000
# - MinIO credentials from minio-secrets.env
# - Nomad address: http://84.8.137.209:4646
# - Nomad token from nomad-token.env

# Run test workflow
nextflow run hello -c nextflow/nextflow.minio.config -w s3://nextflow-work/test
```

## Security Checklist

- [x] Nomad ACL enabled
- [x] Bootstrap token generated and saved
- [x] Client node registered with ACL token
- [x] Node policy created for client registration
- [x] MinIO credentials generated
- [x] All secrets stored with 600 permissions
- [x] Firewall rules configured (ports 4646, 9000, 9001 restricted to your IP)
- [x] SSH keys configured
- [ ] MinIO deployed
- [ ] MinIO buckets created
- [ ] Nextflow configured and tested

## Important Notes

### Security
- **NEVER commit credentials to version control**
- All secret files are in `.gitignore`
- Store bootstrap token in a secure vault (1Password, etc.)
- Rotate credentials regularly

### Network Access
- SSH, Nomad API, and MinIO are restricted to: **146.232.174.192/32**
- If your IP changes, update `ssh_source_cidr` in `terraform.tfvars` and reapply

### Backup
Backup these files to a secure location:
- `nomad-token.env` - Nomad ACL bootstrap token
- `minio-secrets.env` - MinIO credentials
- `/etc/nomad.d/secrets/` directory on server

### Support
- **Deployment Guide**: See `DEPLOYMENT_GUIDE.md`
- **Security Details**: See `SECURITY_IMPLEMENTATION.md`
- **MinIO Deployment**: See `nomad-jobs/MINIO_DEPLOYMENT.md`

## Troubleshooting

### Can't connect to Nomad
1. Check your IP hasn't changed: `curl ifconfig.me`
2. Verify token is set: `echo $NOMAD_TOKEN`
3. Check server is running: `ssh ubuntu@84.8.137.209 "sudo systemctl status nomad"`

### ACL Permission Denied
```bash
# Make sure token is set
source nomad-token.env
nomad status
```

### Client Not Registered
The client may take a few minutes to register. Check:
```bash
# On server
ssh ubuntu@84.8.137.209
sudo journalctl -u nomad -f

# On client
ssh -J ubuntu@84.8.137.209 ubuntu@10.0.2.122
sudo journalctl -u nomad -f
```

## Quick Reference Commands

```bash
# Source credentials
source nomad-token.env
source minio-secrets.env

# Nomad operations
nomad status
nomad node status
nomad job run <job-file>
nomad job status <job-name>
nomad alloc logs <alloc-id>

# MinIO operations
mc ls nomad-minio
mc cp file.txt nomad-minio/bucket/
mc cat nomad-minio/bucket/file.txt

# SSH operations
ssh nomad-server
ssh nomad-client
```

---

**Generated**: February 24, 2026  
**Region**: af-johannesburg-1 (Johannesburg)  
**Project**: nomadjhb
