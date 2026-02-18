variable "compartment_id" {
  type        = string
}

variable "availability_domain_name" {
  type        = string
}

variable "instance_image_ocid" {
  type        = string
}

variable "shape" {
  type = string
}

variable "ssh_public" {
  type        = string
}


variable "private_subnet_id" {
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

variable "nsg_id" {
  type = string
}

variable "fss_mount_target_ip" {
  type        = string
}

variable "fss_export_path" {
  type        = string
}
