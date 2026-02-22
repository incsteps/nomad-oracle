# Terraform Nomad Cluster on Oracle Cloud Infrastructure (OCI)

This project provides Terraform modules to deploy a Hashicorp Nomad cluster on Oracle Cloud Infrastructure (OCI). The infrastructure is modularized for flexibility and reusability.

## Architecture

The project consists of the following modules:

- **VCN**: Sets up the networking infrastructure including VCN, subnets, internet gateway, NAT gateway, and security groups.
- **FSS**: Configures a File Storage Service for shared storage between Nomad nodes.
- **Nomad Cluster**: Deploys Nomad servers and clients in a private subnet with Consul for service discovery.
- **Bastion**: Creates a bastion host in the public subnet for secure access to the private Nomad cluster.
- **Minio**: Creates a Minio (AWS) instance

## Prerequisites

### Internet DNS ("A" record)

For example `nomad.incsteps.com`. You will get the IP to use once deployed the stack (as an output)

### Oracle Cloud Account

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
cd nomad-oracle
```


### 3. Deploy the Infrastructure

The `clients/incsteps` directory contains an example client deployment. To deploy it:

1. Prepare keys:

Create a priv/pub key to ssh in new machines

   ```bash
   ssh-keygen -t ed25519 -C "a comment"
   Generating public/private ed25519 key pair.
   Enter file in which to save the key (/home/user/.ssh/id_ed25519):
   ```
Use "./id_ed25519" to generate in the current directory (key pairs will be git ignored)

2. Edit the `terraform.tfvars` file with your specific values.


   ```hcl
   tenancy_ocid         = "ocid1.tenancy.oc1.."
   tenancy_ocid              = "ocid1.tenancy.oc1..aaa"
   compartment_ocid          = "ocid1.compartment.oc1..aaa" # IncSteps
   region                    = "af-johannesburg-1"
   
   project_name              = "incsteps"
   
   vcn_cidr_block            = "10.10.0.0/16"
   public_subnet_cidr_block  = "10.10.1.0/24"
   private_subnet_cidr_block = "10.10.2.0/24"
   ssh_source_cidr           = "0.0.0.0/0"
   
   ssh_public_key_content    = ""
   dev_ssh_public_key_path   = "~/.ssh/id_ed25519.pub"
   
   bastion_instance_shape    = "VM.Standard.E4.Flex"
   nomad_server_count        = 1
   nomad_client_count        = 2
   
   nomad_server_instance_shape = "VM.Standard.E4.Flex"
   nomad_client_instance_shape = "VM.Standard.E4.Flex"
   
   headscale_domain_name = "nomad.incsteps.com"
   headscale_email = "jorge@incsteps.com"
   
   minio_access_key="minioadmin"
   minio_secret_key="minioadmin"
   ```

3. Deploy the client:
   ```bash
   terraform init
   terraform apply
   ```
If all goes well you'll see something as

   ```aiignore
   bastion_ip = "84.8.132.203"
   fss_ip = "10.10.2.167"
   minio_ip = "10.10.2.201"
   nomad_clients_ips = [
     "10.10.2.126",
   ]
   nomad_server_ip = [
     "10.10.2.188",
   ]
   nomad_url = "http://10.10.2.188:4646"
   ```
Update the DNS A record with the bastion_ip value (this is the only public IP)

## Accessing the Nomad Cluster

All instances have the public key installed so you can ssh into it. As they are in a private network
you can use bastion as ProxyJump:

```aiignore
Host incsteps-nomad
  HostName 10.10.2.188
  User ubuntu
  IdentityFile /home/jorge/incsteps/oracle/nomad-oracle/clients/incsteps/id_ed25519

  ProxyJump ubuntu@incsteps-bastion

Host incsteps-bastion
  HostName 84.8.132.203
  User ubuntu
  IdentityFile /home/jorge/incsteps/oracle/nomad-oracle/clients/incsteps/id_ed25519

```


1. SSH to the bastion host:
   ```bash
   ssh incsteps-bastion
   ```
2. SSH to the nomad-server host:
   ```bash
   ssh incsteps-nomad
   ```

## Tailscale

Central idea of this stack is to have a private network deployed in a remote
cloud with a Minio + Nomad Cluster (1 server + n clients) where you can 
run Nextflow pipelines from your localhost

Basically the stack runs a headscale service in the Bastion instance
and a tailscale node in Nomad-server-1 exposing the private network but 
we (the DevOps) need to accept the routes:

in a terminal in nomad-server-1 run

$ sudo tailscale up --login-server https://your.domain.com --force-reauth

it will show you an URL. Open it in a browser and you will obtain the command
to execute in the bastion

open a terminal in the bastion instance and execute the command presented
in the browser (change <USER> with "bastion")

If all goes well now you can join the tailscale network:

Once installed tailscale in your computer execute

$ sudo tailscale login --login-server=https://your.domain.com --accept-routes


Lastly you need to "join" the headscale network running same tailscale command

$ sudo tailscale login --login-server=https://your.domain.com --accept-routes

Create a key-pair in our minio instance:

```
ssh -i private-key minio
cd minio-binaries
./mc alias set minio http://localhost:9000 minioadmin minioadmin
./mc admin accesskey create minio
./mc anonymous set public minio/demo
(grab the credentials into your nextflow.config)
```


## Nextflow

We'll use a bucket of our minio instance as workdir, so we need to create it:

http://100.64.0.2:9001/ (minioadmin/minioadmin)

Run the main.nf

`nextflow run main.nf -w s3://demo/`

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