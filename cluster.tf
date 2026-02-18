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

module "customer_fss" {
  source = "./modules/fss"

  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_ocid
  private_subnet_id        = module.customer_vcn.private_subnet_id
  nsg_id                   = module.customer_vcn.private_nsg_id
  fss_display_name_prefix  = var.project_name
}


module "customer_minio" {
  source              = "./modules/minio"
  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_ocid
  instance_image_ocid      = data.oci_core_images.ubuntu.images.0.id
  shape                    = "VM.Standard3.Flex"

  private_subnet_id   = module.customer_vcn.private_subnet_id
  ssh_public          = local.final_ssh_public_key_content
  nsg_id              = module.customer_vcn.private_nsg_id

  minio_access_key = var.minio_access_key
  minio_secret_key = var.minio_secret_key

  fss_mount_target_ip = module.customer_fss.fss_mount_target_ip_direct
  fss_export_path     = module.customer_fss.fss_export_path
}


module "customer_bastion" {
  source = "./modules/bastion"

  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_ocid
  ssh_public          = local.final_ssh_public_key_content
  instance_image_ocid      = data.oci_core_images.ubuntu.images.0.id
  shape                    = var.bastion_instance_shape
  public_subnet_id         = module.customer_vcn.public_subnet_id
  nsg_id                   = module.customer_vcn.public_nsg_id
  headscale_domain_name    = var.headscale_domain_name
  headscale_email          = var.headscale_email
  letsencrypt_hostname     = var.headscale_domain_name
}

module "customer_nomad" {
  source                   = "./modules/nomad"
  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_ocid
  instance_image_ocid      = data.oci_core_images.ubuntu.images.0.id

  private_subnet_id       = module.customer_vcn.private_subnet_id
  ssh_public          = local.final_ssh_public_key_content
  nsg_id                  = module.customer_vcn.private_nsg_id

  server_shape             = var.nomad_server_instance_shape
  nomad_server_count      = var.nomad_server_count

  client_shape             = var.nomad_client_instance_shape
  nomad_client_count      = var.nomad_client_count
}
