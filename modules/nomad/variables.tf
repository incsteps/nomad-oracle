variable "compartment_id" {
  type = string
}

variable "availability_domain_name" {
  type = string
}

variable "shape" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "nsg_id" {
  type = string
}

variable "instance_image_ocid" {
  description = "OCID de la imagen del sistema operativo para los nodos Nomad."
  type        = string
  # Ejemplo: OCID de una imagen de Oracle Linux 8 o 9
}

variable "nomad_server_count" {
  description = "Número de instancias que actuarán como servidores Nomad (se recomienda un número impar: 1, 3, 5)."
  type        = number
  default     = 1
  validation {
    condition     = var.nomad_server_count % 2 == 1 && var.nomad_server_count > 0
    error_message = "El número de servidores Nomad debe ser impar y mayor que 0 para quorum."
  }
}

variable "nomad_client_count" {
  description = "Número de instancias que actuarán como clientes Nomad."
  type        = number
  default     = 0
}

variable "nomad_version" {
  description = "Versión de Nomad a instalar (ej. '1.5.0')."
  type        = string
  default     = "1.7.5" # Versión actual estable (a Julio 2025)
}

variable "consul_version" {
  description = "Versión de Consul a instalar (ej. '1.15.0')."
  type        = string
  default     = "1.18.0" # Versión actual estable (a Julio 2025)
}
