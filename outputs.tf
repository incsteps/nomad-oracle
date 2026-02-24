
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
