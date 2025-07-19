variable "tenancy_ocid" {
  description = "OCID de la tenancy de Oracle Cloud Infrastructure."
  type        = string
}

variable "compartment_id" {
  description = "OCID del compartimento de OCI donde se desplegará la infraestructura del Cliente A."
  type        = string
}

variable "oci_region" {
  description = "Región de OCI donde se desplegará la infraestructura del Cliente A."
  type        = string
}

variable "client_name" {
  description = "Nombre único del cliente (ej. 'client-a'). Usado para nombrar recursos."
  type        = string
  default     = "incsteps"
}

# Variables para la VCN
variable "vcn_cidr_block" {
  description = "Bloque CIDR para la VCN del Cliente A (ej. '10.10.0.0/16')."
  type        = string
}

variable "vcn_dns_label" {
  description = "Etiqueta DNS para la VCN del Cliente A (ej. 'cliena')."
  type        = string
}

variable "public_subnet_cidr_block" {
  description = "Bloque CIDR para la subred pública del Cliente A (ej. '10.10.1.0/24')."
  type        = string
}

variable "private_subnet_cidr_block" {
  description = "Bloque CIDR para la subred privada del Cliente A (ej. '10.10.2.0/24')."
  type        = string
}

variable "ssh_source_cidr" {
  description = "Bloque CIDR IP desde donde se permitirá el acceso SSH al bastion host del Cliente A (tu IP pública, ej. 'X.X.X.X/32')."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Ruta al archivo de la clave pública SSH (.pub) para inyectar en todas las instancias."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Ruta al archivo de la clave privada"
  type        = string
}

variable "nomad_server_count" {
  description = "Número de servidores Nomad para el Cliente A (debe ser impar)."
  type        = number
  default     = 3
}

variable "nomad_client_count" {
  description = "Número de clientes Nomad para el Cliente A."
  type        = number
  default     = 3
}

variable "nomad_version" {
  description = "Versión de Nomad a instalar en el clúster del Cliente A."
  type        = string
  default     = "1.10.2"
}

variable "consul_version" {
  description = "Versión de Consul a instalar en el clúster del Cliente A."
  type        = string
  default     = "1.18.0"
}

variable "minio_access_key" {
  description = "Clave de acceso de MinIO."
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "Clave secreta de MinIO."
  type        = string
  sensitive   = true
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
