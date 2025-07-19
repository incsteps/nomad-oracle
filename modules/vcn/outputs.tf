
output "vcn_id" {
  description = "OCID de la VCN creada."
  value       = oci_core_vcn.this.id
}

output "cidr_block" {
  value = oci_core_vcn.this.cidr_block
}

output "public_subnet_id" {
  description = "OCID de la subred pública."
  value       = oci_core_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "OCID de la subred privada."
  value       = oci_core_subnet.private_subnet.id
}

output "private_nsg_id" {
  description = "NSG de la subred privada."
  value       = oci_core_network_security_group.private_nsg.id
}

output "public_nsg_id" {
  description = "NSG de la subred public."
  value       = oci_core_network_security_group.public_nsg.id
}
