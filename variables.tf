variable "tenancy_ocid" {
  type = string
}

variable "compartment_ocid" {
  type = string
}


variable "region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "vcn_cidr_block" {
  type = string
}

variable "public_subnet_cidr_block" {
  type = string
}

variable "private_subnet_cidr_block" {
  type = string
}

variable "ssh_source_cidr" {
  type = string
}

variable "ssh_public_key_content" {
  type = string
}

variable "dev_ssh_public_key_path" {
  type    = string
  default = null # must to be 'null'
}

variable "nomad_server_count" {
  type        = number
  default     = 1
  description = "Number of Nomad server nodes (must be odd)"
  validation {
    condition     = var.nomad_server_count % 2 == 1 && var.nomad_server_count > 0
    error_message = "Nomad server count must be greater than 0 and odd."
  }
}

variable "nomad_client_count" {
  type        = number
  default     = 1
  description = "Number of Nomad client nodes to deploy"
}

variable "nomad_server_instance_shape" {
  type        = string
  default     = "VM.Standard.A1.Flex"
  description = "Instance shape for Nomad server (ARM)"
}

variable "nomad_client_instance_shape" {
  type        = string
  default     = "VM.Standard3.Flex"
  description = "Instance shape for Nomad clients (x86)"
}

variable "server_boot_volume_size_gb" {
  type        = number
  default     = 50
  description = "Boot volume size in GB for Nomad server"
}

variable "client_boot_volume_size_gb" {
  type        = number
  default     = 200
  description = "Boot volume size in GB for Nomad clients"
}

variable "object_storage_bucket_name" {
  type        = string
  description = "Name for the OCI Object Storage bucket"
}
