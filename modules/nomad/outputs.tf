output "nomad_server_private_ip" {
  description = "Private IP address of the Nomad server"
  value       = oci_core_instance.nomad_server[0].private_ip
}

output "nomad_server_public_ip" {
  description = "Public IP address of the Nomad server"
  value       = oci_core_instance.nomad_server[0].public_ip
}

output "nomad_clients_private_ips" {
  description = "List of private IP addresses of Nomad clients"
  value       = oci_core_instance.nomad_client.*.private_ip
}

output "nomad_cluster_endpoint" {
  description = "HTTP endpoint for the Nomad cluster"
  value       = "http://${oci_core_instance.nomad_server[0].public_ip}:4646"
}
