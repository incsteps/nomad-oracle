#!/bin/bash
# Quick Start: Deploy Nomad Cluster with ACL and MinIO
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=================================="
echo "Nomad Cluster Quick Start"
echo "=================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform not installed"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "Error: openssl not installed"; exit 1; }
echo "✓ Prerequisites OK"
echo ""

# Step 1: Generate MinIO credentials
echo "Step 1: Generating MinIO credentials..."
if [ -f "$PROJECT_DIR/minio-secrets.env" ]; then
    echo "⚠️  minio-secrets.env already exists. Skipping generation."
    echo "   To regenerate, delete minio-secrets.env and run again."
else
    "$SCRIPT_DIR/generate-minio-secrets.sh"
    echo "✓ MinIO credentials generated"
fi
echo ""

# Step 2: Check terraform.tfvars
echo "Step 2: Checking Terraform configuration..."
if [ ! -f "$PROJECT_DIR/terraform.tfvars" ]; then
    echo "⚠️  terraform.tfvars not found!"
    echo ""
    echo "Please create terraform.tfvars with the following content:"
    echo ""
    cat << 'EOF'
region       = "af-johannesburg-1"
project_name = "nomadjhb"

compartment_ocid = "ocid1.compartment.oc1..xxxxx"
tenancy_ocid     = "ocid1.tenancy.oc1..xxxxx"

vcn_cidr_block            = "10.0.0.0/16"
public_subnet_cidr_block  = "10.0.1.0/24"
private_subnet_cidr_block = "10.0.2.0/24"
ssh_source_cidr           = "YOUR_IP/32"

ssh_public_key_content = "ssh-ed25519 AAAAC3..."

nomad_server_count = 1
nomad_client_count = 1

object_storage_bucket_name = "nomad-jhb-storage"

# Copy these from minio-secrets.env
minio_root_user     = "xxxxxxxxxxxx"
minio_root_password = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
EOF
    echo ""
    echo "After creating terraform.tfvars, run this script again."
    exit 1
fi
echo "✓ terraform.tfvars exists"
echo ""

# Step 3: Initialize Terraform
echo "Step 3: Initializing Terraform..."
cd "$PROJECT_DIR"
terraform init -upgrade
echo "✓ Terraform initialized"
echo ""

# Step 4: Validate configuration
echo "Step 4: Validating Terraform configuration..."
terraform validate
echo "✓ Configuration valid"
echo ""

# Step 5: Deploy infrastructure
echo "Step 5: Deploying infrastructure..."
echo "This will take 5-10 minutes..."
echo ""
read -p "Proceed with deployment? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

TF_VAR_region=af-johannesburg-1 terraform apply -auto-approve

echo ""
echo "✓ Infrastructure deployed"
echo ""

# Step 6: Get server IP
NOMAD_SERVER_IP=$(terraform output -raw nomad_server_public_ip)
echo "Nomad Server IP: $NOMAD_SERVER_IP"
echo ""

# Step 7: Wait for server to be ready
echo "Step 6: Waiting for Nomad server to be ready..."
echo "This takes about 2-3 minutes for cloud-init to complete..."
sleep 60

for i in {1..20}; do
    if ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$NOMAD_SERVER_IP "sudo test -f /etc/nomad.d/secrets/nomad-token.env" 2>/dev/null; then
        echo "✓ Nomad server ready"
        break
    fi
    echo "Waiting... ($i/20)"
    sleep 15
done

# Step 8: Retrieve Nomad token
echo ""
echo "Step 7: Retrieving Nomad ACL token..."
NOMAD_TOKEN=$(ssh -i ~/.ssh/id_ed25519 ubuntu@$NOMAD_SERVER_IP "sudo cat /etc/nomad.d/secrets/nomad-token.env | grep NOMAD_TOKEN | cut -d= -f2")

if [ -z "$NOMAD_TOKEN" ]; then
    echo "⚠️  Could not retrieve Nomad token automatically"
    echo "   SSH to server and run: sudo cat /etc/nomad.d/secrets/nomad-token.env"
else
    echo "✓ Nomad token retrieved"
    
    # Save token locally
    cat > "$PROJECT_DIR/nomad-token.env" << EOF
# Nomad ACL Token - Generated $(date)
export NOMAD_ADDR=http://$NOMAD_SERVER_IP:4646
export NOMAD_TOKEN=$NOMAD_TOKEN
EOF
    chmod 600 "$PROJECT_DIR/nomad-token.env"
    
    echo ""
    echo "Token saved to: nomad-token.env"
    echo "To use Nomad CLI: source nomad-token.env"
fi

echo ""
echo "=================================="
echo "Deployment Complete!"
echo "=================================="
echo ""
echo "Next Steps:"
echo ""
echo "1. Configure Nomad CLI:"
echo "   source nomad-token.env"
echo "   nomad status"
echo ""
echo "2. Prepare MinIO data directory:"
echo "   ssh -i ~/.ssh/id_ed25519 ubuntu@$NOMAD_SERVER_IP"
echo "   sudo mkdir -p /mnt/minio-data"
echo "   sudo chown -R 1000:1000 /mnt/minio-data"
echo "   sudo chmod -R 755 /mnt/minio-data"
echo ""
echo "3. Deploy MinIO:"
echo "   nomad job run nomad-jobs/minio.nomad"
echo ""
echo "4. Access services:"
echo "   - Nomad UI: http://$NOMAD_SERVER_IP:4646"
echo "   - MinIO Console: http://$NOMAD_SERVER_IP:9001"
echo ""
echo "For detailed instructions, see DEPLOYMENT_GUIDE.md"
echo ""
