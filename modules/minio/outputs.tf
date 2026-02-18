output "minio_private_ip" {
  value       = oci_core_instance.minio_instance.private_ip
}

output "minio_instance_id" {
  value       = oci_core_instance.minio_instance.id
}