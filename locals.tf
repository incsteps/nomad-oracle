
locals {
  final_ssh_public_key_content = var.dev_ssh_public_key_path != null ? file(var.dev_ssh_public_key_path) : var.ssh_public_key_content

  # Computed endpoints from infrastructure outputs
  nomad_public_endpoint = "http://${module.customer_nomad.nomad_server_public_ip}:4646"
  minio_endpoint        = "http://${module.customer_nomad.nomad_server_public_ip}:${var.minio_api_port}"
  oci_s3_endpoint       = "https://${data.oci_objectstorage_namespace.this.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}
