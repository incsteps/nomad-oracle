output "minio_private_ip" {
  description = "La dirección IP privada de la instancia MinIO."
  value       = oci_core_instance.minio_instance.private_ip
}

output "minio_instance_id" {
  description = "El OCID de la instancia MinIO."
  value       = oci_core_instance.minio_instance.id
}