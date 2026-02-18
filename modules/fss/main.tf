# modules/fss/main.tf

# 1. Oracle Cloud Infrastructure File System (File System)
resource "oci_file_storage_file_system" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.fss_display_name_prefix}-fs"
  availability_domain = var.availability_domain_name
}

# 2. Oracle Cloud Infrastructure File Storage Mount Target
resource "oci_file_storage_mount_target" "this" {
  compartment_id    = var.compartment_id
  availability_domain = var.availability_domain_name

  subnet_id         = var.private_subnet_id
  display_name      = "${var.fss_display_name_prefix}-mt"
  hostname_label    = var.fss_mount_target_hostname_label

  nsg_ids           = [var.nsg_id]
}

# 3. Oracle Cloud Infrastructure File Storage Export
resource "oci_file_storage_export" "this" {
  export_set_id  = oci_file_storage_mount_target.this.export_set_id
  file_system_id = oci_file_storage_file_system.this.id
  path           = var.fss_export_path
}
