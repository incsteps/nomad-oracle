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

# Deploy MinIO job
resource "nomad_job" "minio" {
  depends_on = [data.external.nomad_bootstrap_token]
  
  jobspec = <<-EOJ
    job "minio" {
      datacenters = ["dc1"]
      type        = "service"
      
      # Note: MinIO will run on any available node
      # In production, use node constraints to place on specific nodes with storage

      group "minio" {
        count = 1

        network {
          port "api" {
            static = 9000
            to     = 9000
          }
          port "console" {
            static = 9001
            to     = 9001
          }
        }

        task "minio-server" {
          driver = "docker"

          config {
            image = "minio/minio:latest"
            ports = ["api", "console"]
            
            args = [
              "server",
              "/data",
              "--console-address",
              ":9001"
            ]

            volumes = [
              "/mnt/minio-data:/data"
            ]
          }

          env {
            MINIO_ROOT_USER     = "${var.minio_root_user}"
            MINIO_ROOT_PASSWORD = "${var.minio_root_password}"
            MINIO_BROWSER       = "on"
          }

          resources {
            cpu    = 2000  # 2 CPUs
            memory = 4096  # 4 GB RAM
          }

          service {
            name = "minio-api"
            port = "api"
            
            tags = [
              "minio",
              "s3",
              "storage"
            ]

            check {
              type     = "http"
              path     = "/minio/health/live"
              interval = "10s"
              timeout  = "2s"
            }
          }

          service {
            name = "minio-console"
            port = "console"
            
            tags = [
              "minio",
              "console",
              "ui"
            ]

            check {
              type     = "tcp"
              interval = "10s"
              timeout  = "2s"
            }
          }
        }
      }
    }
  EOJ
  
  # Prevent job from being stopped on destroy
  purge_on_destroy = false
}
