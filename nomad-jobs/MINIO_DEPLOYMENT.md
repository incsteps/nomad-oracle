# MinIO Deployment on Nomad Cluster

This guide explains how to deploy MinIO as an S3-compatible storage solution on your Nomad cluster to solve the OCI Object Storage chunked encoding issue.

## Why MinIO?

- ✅ **Supports AWS chunked encoding** - Works perfectly with Nextflow 25.x
- ✅ **S3-compatible API** - Drop-in replacement for AWS S3
- ✅ **Runs on your infrastructure** - No external dependencies
- ✅ **High performance** - Better performance than OCI Object Storage for local workloads

## Prerequisites

- Nomad cluster deployed and running
- Security group rules updated (ports 9000, 9001 open)
- SSH access to Nomad server

## Step 1: Apply Terraform Changes

First, update your infrastructure to allow MinIO ports:

```bash
cd /Users/abhi/projects/PHD-pub-nf-nomad/analysis/infrastructure/03_automation/035_terraform/oci-vm-nomad

# Apply Terraform changes to open MinIO ports
TF_VAR_region=af-johannesburg-1 terraform apply
```

This will add security group rules for:
- Port 9000: MinIO S3 API
- Port 9001: MinIO Web Console

## Step 2: Prepare MinIO Data Directory

SSH to the Nomad server and create the data directory:

```bash
# SSH to server
ssh -i ~/.ssh/id_ed25519 ubuntu@92.4.139.74

# Create MinIO data directory
sudo mkdir -p /mnt/minio-data
sudo chown -R 1000:1000 /mnt/minio-data
sudo chmod -R 755 /mnt/minio-data
```

## Step 3: Deploy MinIO via Nomad

Deploy the MinIO job to your Nomad cluster:

```bash
# From your local machine
export NOMAD_ADDR=http://92.4.139.74:4646

# Deploy MinIO
nomad job run nomad-jobs/minio.nomad

# Check status
nomad job status minio

# View allocations
nomad alloc status $(nomad job status minio | grep running | awk '{print $1}' | head -1)
```

## Step 4: Verify MinIO is Running

Check MinIO health:

```bash
# Check API endpoint
curl http://92.4.139.74:9000/minio/health/live

# Should return: HTTP 200 OK
```

Access MinIO Console:
- URL: http://92.4.139.74:9001
- Username: `minioadmin`
- Password: `minioadmin123`

## Step 5: Create Buckets

Create buckets for Nextflow work directory:

```bash
# Install MinIO client (mc)
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure mc
mc alias set myminio http://92.4.139.74:9000 minioadmin minioadmin123

# Create bucket for Nextflow
mc mb myminio/nextflow-work
mc mb myminio/nextflow-results

# List buckets
mc ls myminio
```

## Step 6: Test with Nextflow

Now you can use MinIO with Nextflow:

```bash
# Use the MinIO configuration
nextflow run hello \
  -c nextflow/nextflow.minio.config \
  -w s3://nextflow-work/hello-test

# Should work without chunked encoding errors!
```

## Security Considerations

### Current Setup (Development)
- ✅ Ports 9000, 9001 restricted to your IP only
- ⚠️ Using default credentials (minioadmin/minioadmin123)
- ⚠️ HTTP only (no TLS)

### Production Recommendations

1. **Change Default Credentials**:
   ```hcl
   // In minio.nomad
   env {
     MINIO_ROOT_USER     = "your-secure-username"
     MINIO_ROOT_PASSWORD = "your-secure-password-min-8-chars"
   }
   ```

2. **Enable TLS**:
   - Generate SSL certificates
   - Mount certificates in MinIO container
   - Set `MINIO_TLS_CERT_FILE` and `MINIO_TLS_KEY_FILE`

3. **Use IAM Policies**:
   - Create specific users with limited permissions
   - Don't use root credentials in Nextflow

4. **Enable Bucket Versioning**:
   ```bash
   mc version enable myminio/nextflow-work
   ```

5. **Set Up Bucket Lifecycle**:
   ```bash
   # Auto-delete old work files after 7 days
   mc ilm add --expiry-days 7 myminio/nextflow-work
   ```

## Resource Allocation

Current allocation per MinIO instance:
- CPU: 1 core (1000 MHz)
- Memory: 2 GB RAM
- Storage: Unlimited (uses server disk at `/mnt/minio-data`)

To modify resources, edit `nomad-jobs/minio.nomad`:

```hcl
resources {
  cpu    = 2000  # 2 CPUs
  memory = 4096  # 4 GB RAM
}
```

## Monitoring

### Check MinIO Logs

```bash
# Find allocation ID
export ALLOC_ID=$(nomad job status minio | grep running | awk '{print $1}' | head -1)

# View logs
nomad alloc logs $ALLOC_ID

# Follow logs
nomad alloc logs -f $ALLOC_ID
```

### MinIO Metrics

MinIO exposes Prometheus metrics at:
- http://92.4.139.74:9000/minio/v2/metrics/cluster

## Backup and Restore

### Backup MinIO Data

```bash
# SSH to server
ssh -i ~/.ssh/id_ed25519 ubuntu@92.4.139.74

# Create backup
sudo tar -czf minio-backup-$(date +%Y%m%d).tar.gz /mnt/minio-data

# Download to local machine
scp -i ~/.ssh/id_ed25519 ubuntu@92.4.139.74:~/minio-backup-*.tar.gz ./
```

### Restore MinIO Data

```bash
# Upload backup to server
scp -i ~/.ssh/id_ed25519 minio-backup-*.tar.gz ubuntu@92.4.139.74:~/

# SSH to server
ssh -i ~/.ssh/id_ed25519 ubuntu@92.4.139.74

# Stop MinIO
nomad job stop minio

# Restore data
sudo rm -rf /mnt/minio-data/*
sudo tar -xzf minio-backup-*.tar.gz -C /

# Restart MinIO
nomad job run /path/to/minio.nomad
```

## Scaling MinIO

### Single Node (Current Setup)
- Good for: Development, small workloads
- Limitations: Single point of failure, limited performance

### Distributed Mode (Future)
To deploy distributed MinIO across multiple nodes:

```hcl
group "minio" {
  count = 4  // Minimum 4 nodes for distributed mode
  
  task "minio-server" {
    args = [
      "server",
      "http://server-{1...4}/mnt/minio-data",
      "--console-address", ":9001"
    ]
  }
}
```

## Troubleshooting

### MinIO Won't Start

Check logs:
```bash
nomad alloc logs $(nomad job status minio | grep running | awk '{print $1}' | head -1)
```

Common issues:
- Port already in use
- Insufficient disk space
- Permission issues on `/mnt/minio-data`

### Can't Access MinIO Console

1. Check security group rules are applied
2. Verify your IP matches `ssh_source_cidr` in terraform.tfvars
3. Check MinIO is running: `nomad job status minio`

### Nextflow Still Has Errors

1. Verify MinIO endpoint is accessible:
   ```bash
   curl http://92.4.139.74:9000/minio/health/live
   ```

2. Check bucket exists:
   ```bash
   mc ls myminio/nextflow-work
   ```

3. Verify Nextflow config has correct endpoint

## Next Steps

1. ✅ Deploy MinIO
2. ✅ Test with Nextflow
3. 🔄 Change default credentials
4. 🔄 Set up automated backups
5. 🔄 Configure lifecycle policies
6. 🔄 Enable TLS for production

## References

- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [MinIO with Nomad](https://www.nomadproject.io/docs/integrations/minio)
- [Nextflow AWS Configuration](https://www.nextflow.io/docs/latest/amazons3.html)
