# OCI Object Storage Chunked Encoding Issue

## Problem

Nextflow 25.x uses AWS SDK v2 which enforces chunked encoding for S3 uploads. OCI Object Storage's S3 compatibility API does not support chunked encoding, resulting in:

```
ERROR ~ AWS chunked encoding not supported. (Service: S3, Status Code: 501)
```

## Root Cause

- Nextflow 25.x → AWS SDK v2 → Requires chunked encoding
- OCI Object Storage S3 API → Does NOT support chunked encoding (HTTP 501)
- AWS SDK v2 does not have a way to disable chunked encoding via configuration

## Current Status

✅ **Nomad cluster is working** - Jobs are being submitted successfully
❌ **S3 work directory fails** - Cannot use OCI Object Storage as work directory
✅ **Local work directory works** - But not accessible from remote Nomad cluster

## Workarounds

### Option 1: Use Nextflow Running on Nomad Server (RECOMMENDED)

Run Nextflow directly on the Nomad server where it can access shared storage:

```bash
# SSH to Nomad server
ssh -i ~/.ssh/id_ed25519 ubuntu@92.4.139.74

# Install Nextflow on the server
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/

# Create a local work directory
mkdir -p /mnt/nomad-work

# Run workflows with local work directory
nextflow run hello -c /path/to/nextflow.ignore.config -w /mnt/nomad-work
```

### Option 2: Use NFS Shared Storage

1. Set up NFS server on one of the Nomad nodes
2. Mount NFS on all Nomad nodes
3. Use NFS path as work directory

### Option 3: Downgrade to Nextflow 23.x (Uses AWS SDK v1)

Nextflow 23.x uses AWS SDK v1 which allows disabling chunked encoding:

```bash
# Install specific version
export NXF_VER=23.10.1
curl -s https://get.nextflow.io | bash

# Or via brew
brew install nextflow@23
```

**Note**: This is not recommended as you lose newer features and security updates.

### Option 4: Use Pre-signed URLs (Experimental)

Configure Nextflow to use pre-signed URLs for S3 access, which bypasses chunked encoding.

## Recommended Solution

**Run Nextflow on the Nomad server itself** with a local work directory:

1. The Nomad server has access to all client nodes
2. Use local filesystem for work directory
3. Publish results to OCI Object Storage at the end

```groovy
process {
    executor = "nomad"
    
    publishDir = [
        path: 's3://nomad-jhb-storage/results',
        mode: 'copy'
    ]
}
```

## Alternative: Use MinIO

Deploy MinIO on the Nomad cluster as an S3-compatible storage that supports chunked encoding:

```bash
# Deploy MinIO via Nomad
nomad job run minio.nomad

# Configure Nextflow to use MinIO
aws {
    accessKey = 'minioadmin'
    secretKey = 'minioadmin'
    client {
        endpoint = 'http://minio.service.consul:9000'
        s3PathStyleAccess = true
    }
}
```

## Status Updates

- **Issue Reported**: Nextflow GitHub issue #XXXX
- **Tracking**: OCI Object Storage team aware
- **Workaround**: Use local filesystem or MinIO

## References

- [AWS SDK v2 Chunked Encoding](https://github.com/aws/aws-sdk-java-v2/issues/1644)
- [OCI S3 Compatibility](https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm)
- [Nextflow AWS Configuration](https://www.nextflow.io/docs/latest/amazons3.html)
