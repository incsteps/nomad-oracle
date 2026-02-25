
output "nomad_server_public_ip" {
  value       = module.customer_nomad.nomad_server_public_ip
  description = "Public IP address of the Nomad server"
}

output "nomad_server_private_ip" {
  value       = module.customer_nomad.nomad_server_private_ip
  description = "Private IP address of the Nomad server"
}

output "nomad_clients_ips" {
  value       = module.customer_nomad.nomad_clients_private_ips
  description = "Private IP addresses of Nomad clients"
}

output "nomad_url" {
  value       = module.customer_nomad.nomad_cluster_endpoint
  description = "Nomad cluster HTTP endpoint"
}

output "object_storage_bucket_name" {
  value       = module.customer_object_storage.bucket_name
  description = "Name of the OCI Object Storage bucket"
}

output "object_storage_namespace" {
  value       = module.customer_object_storage.bucket_namespace
  description = "Namespace of the OCI Object Storage bucket"
}

output "nomad_bootstrap_token" {
  value       = data.external.nomad_bootstrap_token.result.token
  description = "Nomad ACL bootstrap token (management access)"
  sensitive   = true
}

output "nomad_client_token" {
  value       = try(data.external.nomad_client_token.result.token, "not-yet-created")
  description = "Nomad client registration token"
  sensitive   = true
}

output "minio_endpoint" {
  value       = "http://${module.customer_nomad.nomad_server_public_ip}:9000"
  description = "MinIO S3 API endpoint"
}

output "minio_console" {
  value       = "http://${module.customer_nomad.nomad_server_public_ip}:9001"
  description = "MinIO web console URL"
}

output "minio_credentials" {
  value = {
    username = var.minio_root_user
    password = var.minio_root_password
  }
  description = "MinIO access credentials"
  sensitive   = true
}

output "s3_endpoint" {
  value       = local.minio_endpoint
  description = "MinIO S3 endpoint (auto-computed from server IP)"
}

output "fusionfs_bucket" {
  value       = var.fusionfs_bucket
  description = "S3 bucket for Nextflow FusionFS workDir"
}

output "usage" {
  value = <<-EOT

    === OCI Nomad + MinIO ===

    Nextflow configs have been auto-generated in generated/.

    1. Source the env file:
       source generated/env.sh     # bash/zsh
       source generated/env.fish   # fish

    2. Run with FusionFS + MinIO (S3 workDir via MinIO on server):
       nextflow run nextflow-io/hello -c generated/nextflow.config -profile fusion_minio

    3. Run with FusionFS + OCI Object Storage:
       nextflow run nextflow-io/hello -c generated/nextflow.config -profile fusion_oci

    4. Nomad UI:       ${local.nomad_public_endpoint}
    5. MinIO console:  http://${module.customer_nomad.nomad_server_public_ip}:${var.minio_console_port}

    6. Tear down:
       terraform destroy

  EOT
  description = "Usage instructions"
}
