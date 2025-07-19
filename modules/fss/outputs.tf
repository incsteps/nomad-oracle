# modules/fss/outputs.tf

output "file_system_id" {
  description = "The OCID of the File Storage File System."
  value       = oci_file_storage_file_system.this.id
}

output "mount_target_id" {
  description = "The OCID of the File Storage Mount Target."
  value       = oci_file_storage_mount_target.this.id
}

output "mount_target_ip_address" {
  description = "The IP address of the FSS Mount Target."
  value       = oci_file_storage_mount_target.this.private_ip_ids[0] # Asume una única IP
}

output "fss_export_path" {
  description = "The export path of the FSS."
  value       = oci_file_storage_export.this.path
}

output "fss_mount_target_ip_direct" {
  description = "The IP address of the FSS Mount Target."
  value       = oci_file_storage_mount_target.this.ip_address
}

output "fss_mount_command" {
  description = "Example mount command for a Linux instance."
  value       = "${oci_file_storage_mount_target.this.ip_address}:${oci_file_storage_export.this.path}"
}