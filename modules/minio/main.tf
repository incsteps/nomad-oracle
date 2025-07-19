resource "oci_core_instance" "minio_instance" {
  availability_domain = var.availability_domain_name
  compartment_id = var.compartment_id
  defined_tags = {
    "Oracle-Tags.CreatedBy" = "jorge aguilera"
  }
  display_name = "minio"

  shape = var.shape
  shape_config {
    ocpus         = 1
    memory_in_gbs = 16
  }

  source_details {
    is_preserve_boot_volume_enabled = false
    source_id = var.instance_image_ocid
    source_type = "image"
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(templatefile("${path.module}/scripts/install_minio.sh", {
      minio_access_key     = var.minio_access_key
      minio_secret_key     = var.minio_secret_key
      minio_data_path      = "/mnt/minio_data"
      fss_mount_target_ip  = var.fss_mount_target_ip
      fss_export_path      = var.fss_export_path
    }))
  }

  freeform_tags = {
    "Project"   = "MinioService"
  }

  create_vnic_details {
    subnet_id = var.private_subnet_id
    assign_public_ip = false
    nsg_ids = [var.nsg_id]
  }
}
