output "fss_ip" {
  value = module.customer_fss.fss_mount_target_ip_direct
}

output "bastion_ip" {
  value = module.customer_bastion.bastion_public_ip
}

output "minio_ip" {
  value = module.customer_minio.minio_private_ip
}

output "nomad_server_ip" {
  value = module.customer_nomad.nomad_servers_private_ips
}

output "nomad_clients_ips" {
  value = module.customer_nomad.nomad_clients_private_ips
}

output "nomad_url" {
  value = module.customer_nomad.nomad_cluster_endpoint
}
