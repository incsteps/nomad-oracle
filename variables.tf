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

variable "server_ocpus" {
  type        = number
  default     = 2
  description = "Number of OCPUs for Nomad server"
}

variable "server_memory_gb" {
  type        = number
  default     = 12
  description = "Memory in GB for Nomad server"
}

variable "client_boot_volume_size_gb" {
  type        = number
  default     = 200
  description = "Boot volume size in GB for Nomad clients"
}

variable "client_ocpus" {
  type        = number
  default     = 4
  description = "Number of OCPUs for Nomad clients"
}

variable "client_memory_gb" {
  type        = number
  default     = 12
  description = "Memory in GB for Nomad clients"
}

variable "object_storage_bucket_name" {
  type        = string
  description = "Name for the OCI Object Storage bucket"
}

variable "minio_root_user" {
  type        = string
  description = "MinIO root username"
  sensitive   = true
}

variable "minio_root_password" {
  type        = string
  description = "MinIO root password"
  sensitive   = true
}

variable "minio_api_access_key" {
  type        = string
  description = "MinIO API access key (service account). Used in generated Nextflow config."
  sensitive   = true
}

variable "minio_api_secret_key" {
  type        = string
  description = "MinIO API secret key (service account). Used in generated Nextflow config."
  sensitive   = true
}

variable "minio_api_port" {
  type        = number
  default     = 9000
  description = "Port for MinIO S3 API on the server"
}

variable "minio_console_port" {
  type        = number
  default     = 9001
  description = "Port for MinIO web console on the server"
}

variable "fusionfs_bucket" {
  type        = string
  default     = "fusionfs"
  description = "S3 bucket name for Nextflow FusionFS workDir"
}

variable "nf_nomad_plugin_version" {
  type        = string
  default     = "0.4.0-edge2"
  description = "nf-nomad Nextflow plugin version"
}

variable "minio_default_buckets" {
  type        = string
  default     = "nfresults,fusionfs"
  description = "Comma-separated list of buckets to auto-create on MinIO after deployment"
}
