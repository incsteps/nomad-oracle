# Terraform Nomad Cluster on Oracle Cloud Infrastructure (OCI)

This project provides Terraform modules to deploy a Hashicorp Nomad cluster on Oracle Cloud Infrastructure (OCI). The infrastructure is modularized for flexibility and reusability.

## Architecture

The project consists of the following modules:

- **VCN**: Sets up the networking infrastructure including VCN, subnets, internet gateway, NAT gateway, and security groups.
- **FSS**: Configures a File Storage Service for shared storage between Nomad nodes.
- **Nomad Cluster**: Deploys Nomad servers and clients in a private subnet with Consul for service discovery.
- **Bastion**: Creates a bastion host in the public subnet for secure access to the private Nomad cluster.

Additionally, there's a `clients` directory containing an example client deployment.

## Prerequisites

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
cd tf-nomad
```

### 2. Configure Terraform Variables

Create a `terraform.tfvars` file in the root directory:

```hcl
tenancy_ocid         = "ocid1.tenancy.oc1.."
user_ocid            = "ocid1.user.oc1.."
fingerprint          = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
private_key_path     = "~/.oci/oci_api_key.pem"
region               = "eu-madrid-1"  # Change to your preferred region
```

### 3. Deploy the Infrastructure


## Example Client Deployment

The `clients/incsteps` directory contains an example client deployment. To deploy it:

1. Navigate to the client directory:
   ```bash
   cd clients/incsteps
   ```
Create a priv/pub key to ssh in new machines

   ```bash
   ssh-keygen -t ed25519 -C "a comment"
   Generating public/private ed25519 key pair.
   Enter file in which to save the key (/home/user/.ssh/id_ed25519):
   ```
Use "./id_ed25519" to generate in the current directory (private key will git ignored)


2. Create a `terraform.tfvars` file based on the example:
   ```bash
   cp terraform.tfvars.examples terraform.tfvars
   ```

3. Edit the `terraform.tfvars` file with your specific values.

4. Deploy the client:
   ```bash
   terraform init
   terraform apply
   ```

## Accessing the Nomad Cluster

1. SSH to the bastion host:
   ```bash
   ssh -i <your-private-key> opc@<bastion-public-ip>
   ```

2. From the bastion, access the Nomad servers or clients:
   ```bash
   ssh opc@<nomad-server-private-ip>
   ```

3. Access the Nomad UI by setting up an SSH tunnel:
   ```bash
   ssh -i <your-private-key> -L 4646:nomad-server-1:4646 opc@<bastion-public-ip>
   ```
   Then open http://localhost:4646 in your browser.

## Module Descriptions

### VCN Module

Creates the network infrastructure including:
- Virtual Cloud Network (VCN)
- Internet Gateway
- NAT Gateway
- Service Gateway
- Public and private subnets
- Route tables
- Security groups

### FSS Module

Sets up a File Storage Service for shared storage:
- File System
- Mount Target
- Export

### Nomad Cluster Module

Deploys the Nomad cluster:
- Nomad servers (with Consul servers)
- Nomad clients
- Cloud-init configuration for automatic setup

### Bastion Module

Creates a bastion host for secure access:
- Public-facing instance
- Security group rules for SSH access
- Cloud-init configuration

## License

This project is licensed under the MIT License - see the LICENSE file for details.