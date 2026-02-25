variable "compartment_id" {
  type = string
}

variable "availability_domain_name" {
  type = string
}

variable "server_shape" {
  type = string
}

variable "client_shape" {
  type = string
}


variable "ssh_public" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "public_nsg_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "private_nsg_id" {
  type = string
}

variable "server_image_ocid" {
  description = "OCID of the OS image for Nomad server (ARM)"
  type        = string
}

variable "client_image_ocid" {
  description = "OCID of the OS image for Nomad clients (x86)"
  type        = string
}

variable "nomad_server_count" {
  type    = number
  default = 1
  validation {
    condition     = var.nomad_server_count % 2 == 1 && var.nomad_server_count > 0
    error_message = "Nomad server must to be greater than 0 and odd."
  }
}

variable "nomad_client_count" {
  type    = number
  default = 0
}

variable "server_boot_volume_size" {
  type        = number
  default     = 50
  description = "Boot volume size in GB for server"
}

variable "server_ocpus" {
  type        = number
  default     = 2
  description = "Number of OCPUs for server"
}

variable "server_memory_gb" {
  type        = number
  default     = 12
  description = "Memory in GB for server"
}

variable "client_boot_volume_size" {
  type        = number
  default     = 200
  description = "Boot volume size in GB for clients"
}

variable "client_ocpus" {
  type        = number
  default     = 4
  description = "Number of OCPUs for clients"
}

variable "client_memory_gb" {
  type        = number
  default     = 18
  description = "Memory in GB for clients"
}

variable "nomad_version" {
  type    = string
  default = "1.11.2"
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
