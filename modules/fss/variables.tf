# modules/fss/variables.tf

variable "compartment_id" {
  description = "OCID of the compartment where FSS resources will be created."
  type        = string
}

variable "availability_domain_name" {
  description = "El nombre específico del Availability Domain donde se desplegará el bastion host (ej. 'AD-1')."
  type        = string
  # No ponemos un default aquí; queremos que el consumidor del módulo lo especifique,
  # o si queremos un default, podríamos usar el mismo data source que tenías antes,
  # pero al menos hacerlo explícito.
}

variable "private_subnet_id" {
  description = "OCID of the private subnet where the FSS Mount Target will reside."
  type        = string
}

variable "nsg_id" {
  type = string
}

variable "fss_display_name_prefix" {
  description = "Prefix for FSS resource display names (e.g., 'nomad-cluster')."
  type        = string
}

variable "fss_export_path" {
  description = "The path for the FSS export (e.g., '/nomad_shared'). Must start with /."
  type        = string
  default     = "/nomad_shared" # Valor por defecto común
}

variable "fss_mount_target_hostname_label" {
  description = "Hostname label for the FSS Mount Target."
  type        = string
  default     = "fss-mt"
}