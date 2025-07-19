# modules/nomad_cluster/outputs.tf

output "nomad_servers_private_ips" {
  description = "Lista de direcciones IP privadas de los servidores Nomad."
  value       = oci_core_instance.nomad_server.*.private_ip
}


output "nomad_clients_private_ips" {
  description = "Lista de direcciones IP privadas de los clientes Nomad."
  value       = oci_core_instance.nomad_client.*.private_ip
}

output "nomad_cluster_endpoint" {
  description = "Endpoint HTTP del clúster Nomad (puede ser la IP de un servidor)."
  # Esto es un ejemplo. En producción, se usaría un Load Balancer o DNS.
  value = length(oci_core_instance.nomad_server.*.private_ip) > 0 ? "http://${oci_core_instance.nomad_server[0].private_ip}:4646" : "No servers deployed"
}