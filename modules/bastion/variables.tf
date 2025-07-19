variable "compartment_id" {
  type        = string
}

variable "availability_domain_name" {
  type        = string
}

variable "instance_image_ocid" {
  type = string
}

variable "shape" {
  type = string
}

variable "ssh_public_key_path" {
  type        = string
}

variable "public_subnet_id" {
  type = string
}

variable "nsg_id" {
  type = string
}

variable "headscale_domain_name" {
  type        = string
}

variable "headscale_email" {
  type        = string
}

variable "letsencrypt_hostname" {
  type = string
}
