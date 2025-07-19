# modules/vcn/variables.tf

variable "compartment_id" {
  description = "OCID del compartimento donde se crearán los recursos de red."
  type        = string
}

variable "vcn_display_name" {
  description = "Nombre de visualización para la VCN (usado también para nombrar otros recursos)."
  type        = string
}

variable "vcn_cidr_block" {
  description = "Bloque CIDR para la VCN (ej. '10.0.0.0/16')."
  type        = string
}

variable "vcn_dns_label" {
  description = "Etiqueta DNS única para la VCN (max 15 caracteres, solo letras minúsculas, números y guiones)."
  type        = string
}

variable "is_ipv6_enabled" {
  description = "Define si la VCN debe tener IPv6 habilitado."
  type        = bool
  default     = false
}

variable "public_subnet_cidr_block" {
  description = "Bloque CIDR para la subred pública (ej. '10.0.1.0/24')."
  type        = string
}

variable "private_subnet_cidr_block" {
  description = "Bloque CIDR para la subred privada (ej. '10.0.2.0/24')."
  type        = string
}

variable "ssh_source_cidr" {
  description = "your IP ej. 'X.X.X.X/32'."
  type        = string
}
