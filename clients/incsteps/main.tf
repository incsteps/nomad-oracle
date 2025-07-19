terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu22" {
  compartment_id = var.compartment_id
  display_name   = "Canonical-Ubuntu-24.04-2025.05.20-0"
}

module "customer_vcn" {
  source = "../../modules/vcn"

  compartment_id            = var.compartment_id
  vcn_display_name          = "${var.client_name}-vcn"
  vcn_cidr_block            = var.vcn_cidr_block
  vcn_dns_label             = var.vcn_dns_label
  is_ipv6_enabled           = false
  public_subnet_cidr_block  = var.public_subnet_cidr_block
  private_subnet_cidr_block = var.private_subnet_cidr_block
  ssh_source_cidr           = var.ssh_source_cidr
}

module "customer_fss" {
  source = "../../modules/fss"

  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_id
  private_subnet_id        = module.customer_vcn.private_subnet_id
  nsg_id                   = module.customer_vcn.private_nsg_id
  fss_display_name_prefix  = "${var.client_name}-fss"

}

module "customer_bastion" {
  source = "../../modules/bastion"

  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_id
  ssh_public_key_path      = var.ssh_public_key_path
  instance_image_ocid      = data.oci_core_images.ubuntu22.images[0].id
  shape                    = "VM.Standard3.Flex"
  public_subnet_id         = module.customer_vcn.public_subnet_id
  nsg_id                   = module.customer_vcn.public_nsg_id
  headscale_domain_name = var.headscale_domain_name
  headscale_email = var.headscale_email
  letsencrypt_hostname = var.letsencrypt_hostname
}

/*
module "customer_headscale" {
  source = "../../modules/headscale"

  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_id
  ssh_public_key_path      = var.ssh_public_key_path
  instance_image_ocid      = data.oci_core_images.ubuntu22.images[0].id
  shape                    = "VM.Standard3.Flex"
  public_subnet_id         = module.customer_vcn.public_subnet_id
  nsg_id                   = module.customer_vcn.public_nsg_id

  headscale_domain_name = var.headscale_domain_name
  headscale_email = var.headscale_email
  letsencrypt_hostname = var.letsencrypt_hostname
}
*/

module "customer_minio" {
  source                   = "../../modules/minio"
  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_id
  instance_image_ocid      = data.oci_core_images.ubuntu22.images[0].id
  shape                    = "VM.Standard3.Flex"

  vcn_id              = module.customer_vcn.vcn_id
  private_subnet_id   = module.customer_vcn.private_subnet_id
  ssh_public_key_path = var.ssh_public_key_path
  ssh_source_cidr     = var.ssh_source_cidr
  nsg_id              = module.customer_vcn.private_nsg_id

  minio_access_key = var.minio_access_key
  minio_secret_key = var.minio_secret_key

  fss_mount_target_ip = module.customer_fss.fss_mount_target_ip_direct
  fss_export_path     = module.customer_fss.fss_export_path
}

module "customer_nomad" {
  source                   = "../../modules/nomad"
  availability_domain_name = data.oci_identity_availability_domains.this.availability_domains[0].name
  compartment_id           = var.compartment_id
  instance_image_ocid      = data.oci_core_images.ubuntu22.images[0].id
  shape                    = "VM.Standard3.Flex"

  private_subnet_id   = module.customer_vcn.private_subnet_id
  ssh_public_key_path = var.ssh_public_key_path
  nsg_id = module.customer_vcn.private_nsg_id

  nomad_server_count = var.nomad_server_count
  nomad_client_count = var.nomad_client_count
}