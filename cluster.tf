module "customer_vcn" {
  source = "./modules/vcn"

  compartment_id            = var.compartment_ocid
  vcn_display_name          = var.project_name
  vcn_cidr_block            = var.vcn_cidr_block
  vcn_dns_label             = var.project_name
  is_ipv6_enabled           = false
  public_subnet_cidr_block  = var.public_subnet_cidr_block
  private_subnet_cidr_block = var.private_subnet_cidr_block
  ssh_source_cidr           = var.ssh_source_cidr
}

module "customer_object_storage" {
  source = "./modules/object_storage"

  compartment_id = var.compartment_ocid
  namespace      = "frvf3pq2ql1y"
  bucket_name    = var.object_storage_bucket_name
}

module "customer_nomad" {
  source                   = "./modules/nomad"
  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_ocid
  server_image_ocid        = data.oci_core_images.ubuntu_arm.images.0.id
  client_image_ocid        = data.oci_core_images.ubuntu_x86.images.0.id

  public_subnet_id         = module.customer_vcn.public_subnet_id
  public_nsg_id            = module.customer_vcn.public_nsg_id
  private_subnet_id        = module.customer_vcn.private_subnet_id
  private_nsg_id           = module.customer_vcn.private_nsg_id
  ssh_public               = local.final_ssh_public_key_content

  server_shape             = var.nomad_server_instance_shape
  server_boot_volume_size  = var.server_boot_volume_size_gb
  server_ocpus             = var.server_ocpus
  server_memory_gb         = var.server_memory_gb
  nomad_server_count       = var.nomad_server_count

  client_shape             = var.nomad_client_instance_shape
  client_boot_volume_size  = var.client_boot_volume_size_gb
  client_ocpus             = var.client_ocpus
  client_memory_gb         = var.client_memory_gb
  nomad_client_count       = var.nomad_client_count

  minio_root_user          = var.minio_root_user
  minio_root_password      = var.minio_root_password
}
