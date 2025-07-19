variable "tenancy_ocid" {
  description = "OCID de la tenancy de Oracle Cloud Infrastructure."
  type        = string
}

variable "user_ocid" {
  description = "OCID del usuario de IAM que Terraform utilizará para autenticarse."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint de la clave API pública asociada al usuario."
  type        = string
}

variable "private_key_path" {
  description = "Ruta al archivo de clave privada (PEM) para la autenticación de la API de OCI."
  type        = string
}

variable "region" {
  description = "Región de OCI donde se desplegarán los recursos."
  type        = string
  default     = "eu-madrid-1" # Ejemplo: Madrid
}