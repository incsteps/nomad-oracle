
locals {
  consul_server_hostname = oci_core_instance.nomad_server[0].private_ip
  consul_server_hostnames = [for instance in oci_core_instance.nomad_server : instance.private_ip]
}

# 1. Server Nomad (y Consul Servers)
resource "oci_core_instance" "nomad_server" {
  count = var.nomad_server_count

  availability_domain = var.availability_domain_name
  compartment_id      = var.compartment_id
  defined_tags = {
    "Oracle-Tags.CreatedBy" = "jorge aguilera"
  }
  display_name = "nomad-server-${count.index + 1}"

  shape = var.server_shape
  shape_config {
    ocpus         = 1
    memory_in_gbs = 16
  }

  source_details {
    is_preserve_boot_volume_enabled = false
    source_id                       = var.instance_image_ocid
    source_type                     = "image"
  }

  freeform_tags = {
    "Project" = "NomadService"
  }

  create_vnic_details {
    subnet_id        = var.private_subnet_id
    assign_public_ip = false
    nsg_ids          = [var.nsg_id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public
    user_data = base64encode(templatefile("${path.module}/cloud-init-server.yaml", {
      consul_retry_join_servers = "nomad-server-1"
      instance_name             = "nomad-server-${count.index + 1}"
      nomad_server_count        = var.nomad_server_count
      consul_version            = var.consul_version
      nomad_version             = var.nomad_version
    }))
  }
}

# 2 Nomad clients

resource "oci_core_instance" "nomad_client" {
  count = var.nomad_client_count # Número de clientes a desplegar

  availability_domain = var.availability_domain_name
  compartment_id      = var.compartment_id
  defined_tags = {
    "Oracle-Tags.CreatedBy" = "jorge aguilera"
  }
  display_name = "nomad-client-${count.index + 1}"

  shape = var.client_shape
  shape_config {
    ocpus         = 1
    memory_in_gbs = 16
  }

  source_details {
    is_preserve_boot_volume_enabled = false
    source_id                       = var.instance_image_ocid
    source_type                     = "image"
  }

  freeform_tags = {
    "Project" = "NomadService"
    "Role"    = "NomadClient"
  }

  create_vnic_details {
    subnet_id        = var.private_subnet_id
    assign_public_ip = false
    nsg_ids          = [var.nsg_id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public
    user_data = base64encode(templatefile("${path.module}/cloud-init-client.yaml", {
      first_nomad_server_hostname = jsonencode(local.consul_server_hostname)
      consul_retry_join_servers   = jsonencode(local.consul_server_hostnames)
      instance_name               = "nomad-client-${count.index + 1}"
      nomad_version               = var.nomad_version
      consul_version              = var.consul_version
    }))
  }

}