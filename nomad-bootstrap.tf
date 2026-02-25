# Wait for Nomad ACL bootstrap and retrieve tokens
resource "null_resource" "wait_for_nomad_bootstrap" {
  depends_on = [module.customer_nomad]

  # Trigger on server IP change
  triggers = {
    server_ip = module.customer_nomad.nomad_server_public_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting 5 minutes for Nomad ACL bootstrap to complete..."
      sleep 300
      
      echo "Verifying bootstrap completion..."
      for i in {1..30}; do
        if ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
           ubuntu@${module.customer_nomad.nomad_server_public_ip} \
           "sudo test -f /etc/nomad.d/secrets/nomad-token.env" 2>/dev/null; then
          echo "Bootstrap token found!"
          exit 0
        fi
        echo "Waiting for bootstrap token... ($i/30)"
        sleep 10
      done
      
      echo "ERROR: Bootstrap token not found after waiting"
      exit 1
    EOT
  }
}

# Fetch Nomad bootstrap token from server
data "external" "nomad_bootstrap_token" {
  depends_on = [null_resource.wait_for_nomad_bootstrap]
  
  program = ["bash", "-c", <<-EOT
    TOKEN=$(ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
      ubuntu@${module.customer_nomad.nomad_server_public_ip} \
      "sudo cat /etc/nomad.d/secrets/nomad-token.env | grep NOMAD_TOKEN | cut -d= -f2")
    
    if [ -z "$TOKEN" ]; then
      echo '{"error":"Failed to retrieve token"}' >&2
      exit 1
    fi
    
    echo "{\"token\":\"$TOKEN\"}"
  EOT
  ]
}

# Fetch client token for documentation/outputs
data "external" "nomad_client_token" {
  depends_on = [null_resource.wait_for_nomad_bootstrap]
  
  program = ["bash", "-c", <<-EOT
    TOKEN=$(ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
      ubuntu@${module.customer_nomad.nomad_server_public_ip} \
      "sudo cat /etc/nomad.d/secrets/client-token.txt 2>/dev/null" || echo "")
    
    if [ -z "$TOKEN" ]; then
      echo "{\"token\":\"not-yet-created\"}"
    else
      echo "{\"token\":\"$TOKEN\"}"
    fi
  EOT
  ]
}

# Configure Nomad provider with bootstrap token
provider "nomad" {
  address   = "http://${module.customer_nomad.nomad_server_public_ip}:4646"
  secret_id = data.external.nomad_bootstrap_token.result.token
}

# Deploy MinIO job (using Nomad service provider, no Consul dependency)
resource "nomad_job" "minio" {
  depends_on = [data.external.nomad_bootstrap_token]

  jobspec = templatefile("${path.module}/nomad-jobs/minio.nomad", {
    minio_root_user     = var.minio_root_user
    minio_root_password = var.minio_root_password
  })

  # Prevent job from being stopped on destroy
  purge_on_destroy = false
}

# --------------------------------------------------------------------------
# Create default buckets and API service account in MinIO
# Runs after the MinIO Nomad job is deployed and healthy.
# Uses SSH to run mc (MinIO Client) on the server.
# --------------------------------------------------------------------------
resource "null_resource" "minio_init" {
  depends_on = [nomad_job.minio]

  triggers = {
    buckets     = var.minio_default_buckets
    credentials = "${var.minio_api_access_key}-${var.minio_api_secret_key}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      SERVER_IP="${module.customer_nomad.nomad_server_public_ip}"
      SSH_CMD="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no ubuntu@$SERVER_IP"

      echo "Waiting for MinIO to be healthy..."
      for i in $(seq 1 30); do
        if curl -sf "http://$SERVER_IP:${var.minio_api_port}/minio/health/live" > /dev/null 2>&1; then
          echo "MinIO is healthy"
          break
        fi
        echo "  waiting... ($i/30)"
        sleep 10
      done

      echo "Installing mc (MinIO Client) on server if needed..."
      $SSH_CMD 'command -v mc >/dev/null 2>&1 || {
        curl -sL https://dl.min.io/client/mc/release/linux-arm64/mc -o /tmp/mc
        sudo mv /tmp/mc /usr/local/bin/mc
        sudo chmod +x /usr/local/bin/mc
      }'          

      echo "Configuring mc alias (using private IP since MinIO binds to host network via Nomad)..."
      $SSH_CMD "PRIV_IP=\$(hostname -I | awk '{print \$1}') && mc alias set minio http://\$PRIV_IP:${var.minio_api_port} '${var.minio_root_user}' '${var.minio_root_password}'"

      echo "Creating API service account..."
      $SSH_CMD "mc admin user svcacct add minio '${var.minio_root_user}' \
        --access-key '${var.minio_api_access_key}' \
        --secret-key '${var.minio_api_secret_key}' || echo 'Service account may already exist'"

      echo "Creating default buckets..."
      $SSH_CMD 'for bucket in $(echo "${var.minio_default_buckets}" | tr "," " "); do
        mc mb --ignore-existing "minio/$bucket"
      done'

      echo "MinIO buckets and API credentials are ready."
    EOT
  }
}
