output "bastion_public_ip" {
  description = "La dirección IP pública del bastion host."
  value       = oci_core_instance.bastion_instance.public_ip
}

output "bastion_private_ip" {
  description = "La dirección IP privada del bastion host."
  value       = oci_core_instance.bastion_instance.private_ip
}
