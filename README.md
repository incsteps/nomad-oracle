# OCI Nomad Cluster for Nextflow

Terraform modules to deploy a Nomad cluster on Oracle Cloud Infrastructure (OCI) with MinIO for running Nextflow pipelines.

## Architecture

- **Nomad Server**: ARM instance (VM.Standard.A1.Flex) in public subnet — runs MinIO
- **Nomad Clients**: x86 instances in private subnet — run Nextflow tasks
- **MinIO**: S3-compatible storage on the server (solves OCI chunked-encoding limitation)
- **ACL enabled**: all Nomad API requests require tokens
- **Auto-generated configs**: Terraform outputs Nextflow config and shell env files with the correct IPs and credentials

## Prerequisites

- OCI account with API keys configured (`oci setup config`)
- Terraform >= 1.0
- SSH key pair (ed25519 recommended)
- Nextflow and the `nf-nomad` plugin

## Usage

### 1. Generate credentials

```bash
./scripts/generate-minio-secrets.sh   # creates minio-secrets.env
```

### 2. Configure `terraform.tfvars`

```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..aaa..."
compartment_ocid = "ocid1.compartment.oc1..aaa..."
region           = "af-johannesburg-1"
project_name     = "nomadjhb"          # no hyphens (OCI DNS label rule)

vcn_cidr_block            = "10.0.0.0/16"
public_subnet_cidr_block  = "10.0.1.0/24"
private_subnet_cidr_block = "10.0.2.0/24"
ssh_source_cidr           = "YOUR_IP/32"   # restricts SSH + Nomad API + MinIO

ssh_public_key_content = "ssh-ed25519 AAAA..."

nomad_server_count = 1
nomad_client_count = 1

object_storage_bucket_name = "nomad-storage"

# from minio-secrets.env
minio_root_user     = "..."
minio_root_password = "..."

# service-account keys for Nextflow (openssl rand -base64 15 / 30)
minio_api_access_key = "..."
minio_api_secret_key = "..."

fusionfs_bucket = "fusionfs"
```

See `variables.tf` for all available variables and defaults.

### 3. Deploy

```bash
terraform init
terraform apply
```

Deployment takes ~8-10 min (infra creation + cloud-init + MinIO job).

Alternatively, `./scripts/quick-start.sh` runs the full flow interactively.

### 4. Run Nextflow

Source the generated env (sets `NOMAD_ADDR` and `NOMAD_TOKEN`):

```bash
source generated/env.sh     # bash/zsh
source generated/env.fish   # fish
```

Run a pipeline with one of the two profiles:

```bash
# FusionFS + MinIO (S3 workDir backed by MinIO on the server)
nextflow run nextflow-io/hello -c generated/nextflow.config -profile fusion_minio

# FusionFS + OCI Object Storage
nextflow run nextflow-io/hello -c generated/nextflow.config -profile fusion_oci
```

> The static configs in `nextflow/*.example` are reference templates. Always use `generated/nextflow.config` for real runs.

## Accessing the cluster

### SSH

```bash
# server (public IP)
ssh -i ./id_ed25519 ubuntu@<server_ip>

# client (via server as jump host)
ssh -J ubuntu@<server_ip> ubuntu@<client_private_ip>
```

### Nomad UI

Open `http://<server_ip>:4646` and enter the ACL token when prompted.

### MinIO console

Open `http://<server_ip>:9001` and log in with the credentials from `minio-secrets.env`.

## Scaling clients

Change `nomad_client_count` in `terraform.tfvars` (or pass it as a CLI var) and re-apply:

```bash
# scale to 3 clients
terraform apply -var="nomad_client_count=3"
```

New clients are created in the private subnet and automatically join the cluster with Docker and Nomad pre-installed via cloud-init. No manual configuration is needed.

You can also adjust per-client resources without changing the count:

```bash
terraform apply \
  -var="nomad_client_count=3" \
  -var="client_ocpus=8" \
  -var="client_memory_gb=24" \
  -var="client_boot_volume_size_gb=500"
```

Defaults: 4 OCPUs, 18 GB memory, 500 GB boot disk per client (see `variables.tf`).

After apply completes, verify the new nodes have joined:

```bash
source generated/env.sh   # or env.fish
nomad node status
```

## Project structure

```
├── *.tf                     # Root Terraform config
├── modules/
│   ├── nomad/               # Server + client instances, cloud-init
│   ├── vcn/                 # VCN, subnets, gateways, security groups
│   └── object_storage/      # OCI Object Storage bucket
├── nomad-jobs/
│   └── minio.nomad          # MinIO Nomad job (reads creds from host secrets)
├── nextflow/
│   ├── main.nf              # Example pipeline
│   └── *.config.example     # Reference Nextflow configs
├── acl-policies/            # Nomad ACL policy templates
├── scripts/
│   ├── quick-start.sh       # Guided deployment
│   ├── generate-minio-secrets.sh
│   └── configure-client-tokens.sh
├── generated/               # (gitignored) auto-generated env + nextflow config
└── schema.yaml              # OCI Resource Manager schema
```

## Cleanup

```bash
terraform destroy
```

## Troubleshooting

**Cannot reach Nomad API** — check that `ssh_source_cidr` matches your current public IP (`curl -s ifconfig.me`).

**Cloud-init still running** — SSH to the server and run `sudo cloud-init status`. Nomad/Docker install takes 1-2 min after instance creation.

**DNS label errors** — `project_name` must contain only alphanumeric characters (no hyphens).

**Shape/image mismatch** — ARM shapes need aarch64 images, x86 shapes need x86_64. The config handles this automatically.

**Wrong region** — explicitly set `TF_VAR_region=<region> terraform apply`, or ensure `region` is correct in `terraform.tfvars`.
