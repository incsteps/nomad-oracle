variable "tenancy_ocid" {
  type        = string
}

variable "compartment_ocid" {
  type        = string
}


variable "region" {
  type        = string
}

variable "project_name" {
  type = string
}

variable "vcn_cidr_block" {
  type        = string
}

variable "public_subnet_cidr_block" {
  type        = string
}

variable "private_subnet_cidr_block" {
  type        = string
}

variable "ssh_source_cidr" {
  type        = string
}

variable "ssh_public_key_content" {
  type        = string
}

variable "dev_ssh_public_key_path" {
  type        = string
  default     = null # must to be 'null'
}

variable "bastion_instance_shape" {
  type = string
  default = "VM.Standard3.Flex"
}

variable "nomad_server_count" {
  type        = number
  default     = 3
}

variable "nomad_client_count" {
  type        = number
  default     = 3
}

variable "nomad_server_instance_shape" {
  type = string
  default = "VM.Standard3.Flex"
}

variable "nomad_client_instance_shape" {
  type = string
  default = "VM.Standard3.Flex"
}

variable "headscale_domain_name" {
  type = string
}

variable "headscale_email" {
  type = string
}


variable "minio_access_key" {
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  type        = string
  sensitive   = true
}