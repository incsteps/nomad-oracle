# Single Nomad Server (ARM, public IP)
resource "oci_core_instance" "nomad_server" {
  count = var.nomad_server_count

  availability_domain = var.availability_domain_name
  compartment_id      = var.compartment_id
  display_name        = "nomad-server-${count.index + 1}"

  shape = var.server_shape
  shape_config {
    ocpus         = var.server_ocpus
    memory_in_gbs = var.server_memory_gb
  }

  source_details {
    boot_volume_size_in_gbs         = var.server_boot_volume_size
    is_preserve_boot_volume_enabled = false
    source_id                       = var.server_image_ocid
    source_type                     = "image"
  }

  freeform_tags = {
    "Project" = "NomadCluster"
    "Role"    = "NomadServer"
  }

  create_vnic_details {
    subnet_id        = var.public_subnet_id
    assign_public_ip = true
    nsg_ids          = [var.public_nsg_id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public
    user_data = base64encode(templatefile("${path.module}/cloud-init-server.yaml", {
      nomad_version       = var.nomad_version
      minio_root_user     = var.minio_root_user
      minio_root_password = var.minio_root_password
    }))
  }
}

# Nomad Clients (scalable)
resource "oci_core_instance" "nomad_client" {
  count = var.nomad_client_count

  availability_domain = var.availability_domain_name
  compartment_id      = var.compartment_id
  display_name        = "nomad-client-${count.index + 1}"

  shape = var.client_shape
  shape_config {
    ocpus         = var.client_ocpus
    memory_in_gbs = var.client_memory_gb
  }

  source_details {
    boot_volume_size_in_gbs         = var.client_boot_volume_size
    is_preserve_boot_volume_enabled = false
    source_id                       = var.client_image_ocid
    source_type                     = "image"
  }

  freeform_tags = {
    "Project" = "NomadCluster"
    "Role"    = "NomadClient"
  }

  create_vnic_details {
    subnet_id        = var.private_subnet_id
    assign_public_ip = false
    nsg_ids          = [var.private_nsg_id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public
    user_data = base64encode(templatefile("${path.module}/cloud-init-client.yaml", {
      nomad_server_ip = oci_core_instance.nomad_server[0].private_ip
      nomad_version   = var.nomad_version
    }))
  }

  depends_on = [oci_core_instance.nomad_server]
}
