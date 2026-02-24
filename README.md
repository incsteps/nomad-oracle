# Terraform Nomad Cluster on Oracle Cloud Infrastructure (OCI)

This project provides Terraform modules to deploy a simplified HashiCorp Nomad cluster on Oracle Cloud Infrastructure (OCI). The infrastructure is modularized for flexibility and reusability.

## Architecture

The project deploys a minimal, production-ready Nomad cluster with the following components:

- **VCN Module**: Networking infrastructure including VCN, public/private subnets, internet gateway, NAT gateway, and security groups
- **Nomad Module**: Single ARM-based Nomad server with public IP + scalable x86 Nomad clients in private subnet
- **Object Storage Module**: OCI Object Storage bucket for cluster-wide data storage

### Infrastructure Overview

- **Nomad Server**: ARM instance (VM.Standard.A1.Flex) in public subnet with 50GB boot disk
- **Nomad Clients**: x86 instances in private subnet with 200GB boot disks, internet access via NAT
- **No Consul**: Direct Nomad server-client communication
- **No Bastion**: Direct SSH access to server via public IP; clients accessible via server as jump host

## Prerequisites

### Oracle Cloud Account

You'll need an active OCI account with appropriate permissions to create resources.

### Terraform

1. Install Terraform (version 1.0 or higher):
   - **Linux/macOS**:
     ```bash
     wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
     unzip terraform_1.5.7_linux_amd64.zip
     sudo mv terraform /usr/local/bin/
     ```
   - **Windows**: Download from [Terraform's website](https://www.terraform.io/downloads.html) and add to your PATH.

2. Verify the installation:
   ```bash
   terraform version
   ```

### OCI CLI

1. Install OCI CLI:
   - **Linux/macOS**:
     ```bash
     bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
     ```
   - **Windows**: Download and run the installer from [OCI CLI website](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm).

2. Configure OCI CLI:
   ```bash
   oci setup config
   ```
   Follow the prompts to set up your OCI configuration.

### OCI API Keys

1. Generate an API key pair:
   ```bash
   mkdir -p ~/.oci
   openssl genrsa -out ~/.oci/oci_api_key.pem 2048
   chmod 600 ~/.oci/oci_api_key.pem
   openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
   ```

2. Upload the public key to your OCI user account through the OCI Console.

## Deployment Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd oci-vm-nomad
```

### 2. Generate SSH Keys

Create an SSH key pair for accessing the instances:

```bash
ssh-keygen -t ed25519 -C "nomad-cluster"
```

When prompted for the file location, you can use `./id_ed25519` to save in the current directory (these files are git-ignored).

### 3. Configure Variables

Create a `terraform.tfvars` file with your specific values:

```hcl
# OCI Configuration
tenancy_ocid              = "ocid1.tenancy.oc1..aaa..."
compartment_ocid          = "ocid1.compartment.oc1..aaa..."
region                    = "us-phoenix-1"

# Project Configuration
project_name              = "my-nomad-cluster"

# Network Configuration
vcn_cidr_block            = "10.0.0.0/16"
public_subnet_cidr_block  = "10.0.1.0/24"
private_subnet_cidr_block = "10.0.2.0/24"
ssh_source_cidr           = "YOUR_IP/32"  # Your public IP for SSH access

# SSH Key Configuration
ssh_public_key_content    = ""
dev_ssh_public_key_path   = "./id_ed25519.pub"  # Path to your public key

# Nomad Configuration
nomad_server_count        = 1  # Must be odd number (1, 3, 5, etc.)
nomad_client_count        = 1  # Can be any number, scales easily

# Instance Shapes (defaults shown)
nomad_server_instance_shape = "VM.Standard.A1.Flex"  # ARM
nomad_client_instance_shape = "VM.Standard3.Flex"    # x86

# Storage Configuration
server_boot_volume_size_gb = 50
client_boot_volume_size_gb = 200

# Object Storage
object_storage_bucket_name = "my-nomad-storage-bucket"
```

### 4. Deploy the Infrastructure

Initialize and apply the Terraform configuration:

```bash
terraform init
terraform plan
terraform apply
```

### 5. Deployment Outputs

After successful deployment, you'll see outputs similar to:

```
nomad_server_public_ip = "150.136.x.x"
nomad_server_private_ip = "10.0.1.10"
nomad_clients_ips = [
  "10.0.2.20",
]
nomad_url = "http://150.136.x.x:4646"
object_storage_bucket_name = "my-nomad-storage-bucket"
object_storage_namespace = "your-namespace"
```

## Accessing the Cluster

### SSH Access

#### Access Nomad Server (Public IP)

```bash
ssh -i ./id_ed25519 ubuntu@<nomad_server_public_ip>
```

#### Access Nomad Clients (via Server as Jump Host)

Add to your `~/.ssh/config`:

```
Host nomad-server
  HostName <nomad_server_public_ip>
  User ubuntu
  IdentityFile /path/to/id_ed25519

Host nomad-client-1
  HostName <nomad_client_private_ip>
  User ubuntu
  IdentityFile /path/to/id_ed25519
  ProxyJump nomad-server
```

Then:

```bash
ssh nomad-server
ssh nomad-client-1
```

### Nomad Web UI

Access the Nomad web interface at:

```
http://<nomad_server_public_ip>:4646
```

### Nomad CLI

Set the Nomad address:

```bash
export NOMAD_ADDR=http://<nomad_server_public_ip>:4646
nomad node status
nomad server members
```

## Scaling Clients

To add more Nomad clients, simply update the `nomad_client_count` variable:

```bash
terraform apply -var="nomad_client_count=3"
```

New clients will automatically:
- Be deployed in the private subnet
- Connect to the Nomad server via private IP
- Have Docker pre-installed and configured
- Join the cluster automatically

## OCI Object Storage Access

The cluster includes an OCI Object Storage bucket. To access it from your Nomad jobs:

1. Configure OCI credentials in your job specification
2. Use the bucket name from the outputs: `object_storage_bucket_name`
3. Use the namespace from the outputs: `object_storage_namespace`

## Module Descriptions

### VCN Module

Creates the network infrastructure:
- Virtual Cloud Network (VCN)
- Internet Gateway (for server public access)
- NAT Gateway (for client internet access)
- Public subnet (for Nomad server)
- Private subnet (for Nomad clients)
- Security groups (SSH + Nomad ports 4646-4648)

### Nomad Module

Deploys the Nomad cluster:
- Single ARM-based Nomad server with public IP
- Scalable x86-based Nomad clients in private subnet
- Docker pre-installed on all nodes
- Automatic cluster formation via cloud-init
- Configurable boot volume sizes

### Object Storage Module

Creates OCI Object Storage:
- Standard tier bucket
- Private access (NoPublicAccess)
- Integrated with cluster namespace

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Troubleshooting

### Check Nomad Server Status

```bash
ssh ubuntu@<nomad_server_public_ip>
sudo systemctl status nomad
sudo journalctl -u nomad -f
```

### Check Client Connection

```bash
ssh -J ubuntu@<nomad_server_public_ip> ubuntu@<client_private_ip>
sudo systemctl status nomad
nomad node status
```

### Firewall Issues

Ensure your `ssh_source_cidr` includes your current public IP address.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
