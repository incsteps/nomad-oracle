# Nextflow Configuration for OCI Nomad Cluster

This directory contains Nextflow configuration for running workflows on the OCI Nomad cluster deployed in Johannesburg.

## Cluster Information

**Deployed Cluster Details:**
- **Region**: af-johannesburg-1 (Africa - Johannesburg)
- **Nomad Server Public IP**: 92.4.139.74
- **Nomad Server Private IP**: 10.0.1.4
- **Nomad Web UI**: http://92.4.139.74:4646
- **Object Storage Bucket**: nomad-jhb-storage
- **Object Storage Namespace**: frvf3pq2ql1y

## Setup Instructions

### 1. Configure OCI Credentials

You need to create OCI access keys for Object Storage access:

1. Go to OCI Console → Identity → Users → Your User
2. Click "Customer Secret Keys" under "Resources"
3. Click "Generate Secret Key"
4. Give it a name (e.g., "nextflow-nomad")
5. Copy the generated key immediately (you won't be able to see it again)

### 2. Update Configuration File

Copy the template and add your credentials:

```bash
cd nextflow/
cp nextflow.ignore.config nextflow.config
```

Edit `nextflow.config` and replace:
- `<YOUR_OCI_ACCESS_KEY>` with the Access Key from step 1
- `<YOUR_OCI_SECRET_KEY>` with the Secret Key from step 1

### 3. Configure S3 Bucket

Create or configure your bucket for Nextflow work directory:

```bash
# Using OCI CLI
oci os bucket create \
  --compartment-id <your-compartment-id> \
  --name nextflow-work \
  --namespace frvf3pq2ql1y

# Or use the existing bucket: nomad-jhb-storage
```

## Running Nextflow Workflows

### Basic Usage

```bash
export NXF_FILE=nextflow/nextflow.config

# Run a simple workflow
nextflow run hello -c $NXF_FILE

# Run with work directory on OCI Object Storage
nextflow run hello \
  -c $NXF_FILE \
  -w s3://nomad-jhb-storage/work
```

### Example Pipeline

```bash
# Run nf-core pipeline
nextflow run nf-core/rnaseq \
  -c nextflow/nextflow.config \
  -w s3://nomad-jhb-storage/rnaseq-work \
  -profile docker \
  --input samplesheet.csv \
  --outdir s3://nomad-jhb-storage/results
```

## Configuration Details

### Nomad Executor

The configuration uses the `nf-nomad` plugin (v0.4.0-edge2) to submit jobs to the Nomad cluster:

```groovy
process {
    executor = "nomad"
}

nomad {
    client {
        address = "http://92.4.139.74:4646"
    }
    jobs {
        deleteOnCompletion = false
    }
}
```

### Fusion File System

Fusion is enabled for efficient data access from OCI Object Storage:

```groovy
wave.enabled = true
fusion.enabled = true
fusion.exportStorageCredentials = true
```

### Docker

All processes run in Docker containers on the Nomad cluster:

```groovy
docker {
    enabled = true
}
```

## Accessing from Different Locations

### From Your Local Machine

Use the public IP address:
```groovy
nomad {
    client {
        address = "http://92.4.139.74:4646"
    }
}
```

Ensure your IP is whitelisted in the Terraform `ssh_source_cidr` variable.

### From Within the VCN

If running Nextflow from another VM in the same VCN:
```groovy
nomad {
    client {
        address = "http://10.0.1.4:4646"
    }
}
```

### From the Nomad Server Itself

```bash
# SSH to the server
ssh -i ~/.ssh/id_ed25519 ubuntu@92.4.139.74

# Use localhost
nomad {
    client {
        address = "http://127.0.0.1:4646"
    }
}
```

## Troubleshooting

### Connection Refused

If you get connection errors:
1. Check your IP is whitelisted: `curl http://92.4.139.74:4646/v1/status/leader`
2. Verify Nomad is running: `ssh ubuntu@92.4.139.74 "sudo systemctl status nomad"`

### Authentication Errors

For OCI Object Storage issues:
1. Verify your access key and secret key are correct
2. Check bucket permissions in OCI Console
3. Test with OCI CLI: `oci os object list --bucket-name nomad-jhb-storage --namespace frvf3pq2ql1y`

### Job Failures

Check Nomad job logs:
```bash
# List jobs
export NOMAD_ADDR=http://92.4.139.74:4646
nomad job status

# View job details
nomad job status <job-id>

# View allocation logs
nomad alloc logs <allocation-id>
```

## Resources

- **nf-nomad Plugin**: https://github.com/nextflow-io/nf-nomad
- **Fusion Documentation**: https://docs.seqera.io/fusion/
- **OCI Object Storage S3 Compatibility**: https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm
- **Nomad Documentation**: https://www.nomadproject.io/docs

## Security Notes

- ⚠️ The `nextflow.config` file contains credentials and should NOT be committed to git
- ⚠️ The `.ignore.config` suffix is used to prevent accidental commits
- ⚠️ Always use the `.gitignore` to exclude credential files
- ⚠️ Consider using environment variables for credentials in production
