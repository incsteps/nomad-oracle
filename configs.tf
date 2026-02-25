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
  file_permission = "0644"
  content         = <<-SH
    export NOMAD_ADDR="${local.nomad_public_endpoint}"
  SH
}

resource "local_file" "env_fish" {
  filename        = "${path.module}/generated/env.fish"
  file_permission = "0644"
  content         = <<-FISH
    set -gx NOMAD_ADDR "${local.nomad_public_endpoint}"
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
        }

        jobs {
            deleteOnCompletion = false
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
