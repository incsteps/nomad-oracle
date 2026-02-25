# --------------------------------------------------------------------------
# Auto-generated configs for Nextflow + Nomad on OCI
# Mirrors the pattern from local-nomad-minio: all IPs and credentials
# are injected from Terraform outputs so nothing is hardcoded.
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Sourceable env files so the user's shell targets the remote Nomad
# Usage:  source generated/env.sh   (bash/zsh)
#         source generated/env.fish  (fish)
# --------------------------------------------------------------------------
resource "local_file" "env_sh" {
  filename        = "${path.module}/generated/env.sh"
  file_permission = "0600"
  content         = <<-SH
    export NOMAD_ADDR="${local.nomad_public_endpoint}"
    export NOMAD_TOKEN="${data.external.nomad_bootstrap_token.result.token}"

    # SSH tunnel for local MinIO access (private IP not directly reachable from your machine).
    # Creates a local interface alias + SSH tunnel so Nextflow can reach the private IP.
    if ! ip addr show lo 2>/dev/null | grep -q ${local.server_private_ip} && \
       ! ifconfig lo0 2>/dev/null | grep -q ${local.server_private_ip}; then
      sudo ifconfig lo0 alias ${local.server_private_ip} 2>/dev/null || true
    fi
    if ! lsof -i :${var.minio_api_port} >/dev/null 2>&1; then
      ssh -f -N -L ${local.server_private_ip}:${var.minio_api_port}:${local.server_private_ip}:${var.minio_api_port} ubuntu@${local.server_public_ip}
      echo "SSH tunnel to MinIO established (${local.server_private_ip}:${var.minio_api_port})"
    fi
  SH
}

resource "local_file" "env_fish" {
  filename        = "${path.module}/generated/env.fish"
  file_permission = "0600"
  content         = <<-FISH
    set -gx NOMAD_ADDR "${local.nomad_public_endpoint}"
    set -gx NOMAD_TOKEN "${data.external.nomad_bootstrap_token.result.token}"

    # SSH tunnel for local MinIO access (private IP not directly reachable from your machine).
    # Creates a local interface alias + SSH tunnel so Nextflow can reach the private IP.
    if not ifconfig lo0 2>/dev/null | grep -q ${local.server_private_ip}
      sudo ifconfig lo0 alias ${local.server_private_ip} 2>/dev/null; or true
    end
    if not lsof -i :${var.minio_api_port} >/dev/null 2>&1
      ssh -f -N -L ${local.server_private_ip}:${var.minio_api_port}:${local.server_private_ip}:${var.minio_api_port} ubuntu@${local.server_public_ip}
      echo "SSH tunnel to MinIO established (${local.server_private_ip}:${var.minio_api_port})"
    end
  FISH
}

# --------------------------------------------------------------------------
# Nextflow config with profiles:
#   fusion_minio – S3 workDir via FusionFS backed by MinIO on the server
#   fusion_oci   – S3 workDir via FusionFS backed by OCI Object Storage
# Usage:
#   nextflow run <pipeline> -c generated/nextflow.config -profile fusion_minio
#   nextflow run <pipeline> -c generated/nextflow.config -profile fusion_oci
# --------------------------------------------------------------------------
resource "local_file" "nextflow_config" {
  filename        = "${path.module}/generated/nextflow.config"
  file_permission = "0644"

  content = <<-NF
    plugins {
        id "nf-nomad@${var.nf_nomad_plugin_version}"
    }

    tower {
        enabled = false
    }

    process {
        executor = "nomad"
    }

    docker {
        enabled = true
    }

    nomad {
        client {
            address = "${local.nomad_public_endpoint}"
            token   = "${data.external.nomad_bootstrap_token.result.token}"
        }

        jobs {
            deleteOnCompletion = false

            // Schedule tasks only on client nodes (x86), not on the ARM server
            // NOTE: nf-nomad expects `constraints` to be a Closure assigned with `=` (see packages/nf-nomad).
            constraints = {
                attr {
                    cpu = [arch: 'amd64']
                }
            }
        }
    }

    // ---- Profiles --------------------------------------------------------

    profiles {

        fusion_minio {
            workDir = "s3://${var.fusionfs_bucket}/work"

            wave.enabled = true
            fusion.enabled = true
            fusion.exportStorageCredentials = true

            aws {
                accessKey = '${var.minio_api_access_key}'
                secretKey = '${var.minio_api_secret_key}'
                region    = 'us-east-1'

                client {
                    // Uses server private IP — reachable from all VCN nodes.
                    // For local Nextflow: source generated/env.sh to start SSH tunnel.
                    endpoint          = "${local.minio_endpoint}"
                    s3PathStyleAccess = true
                    protocol          = "http"
                }
            }
        }

        fusion_oci {
            workDir = "s3://${var.fusionfs_bucket}/work"

            wave.enabled = true
            fusion.enabled = true
            fusion.exportStorageCredentials = true

            aws {
                accessKey = '${var.minio_api_access_key}'
                secretKey = '${var.minio_api_secret_key}'
                region    = '${var.region}'

                client {
                    endpoint          = "${local.oci_s3_endpoint}"
                    s3PathStyleAccess = true
                    protocol          = "https"
                    signerOverride    = "AWSS3V4SignerType"
                }
            }
        }

    }
  NF
}
