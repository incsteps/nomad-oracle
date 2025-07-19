resource "oci_core_instance" "bastion_instance" {
  availability_domain = var.availability_domain_name
  compartment_id = var.compartment_id

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "jorge aguilera"
  }
  display_name = "bastion"

  shape = var.shape
  shape_config {
    ocpus         = 1
    memory_in_gbs = 4
  }

  source_details {
    source_id = var.instance_image_ocid
    source_type = "image"
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data = base64encode(templatefile("${path.module}/cloud-init-bastion.yaml", {
      domain_name = var.headscale_domain_name
      email = var.headscale_email
      letsencrypt_hostname = var.letsencrypt_hostname
    }))
  }

  create_vnic_details {
    subnet_id = var.public_subnet_id
    assign_public_ip = true
    nsg_ids = [var.nsg_id]
  }

}