resource "oci_objectstorage_bucket" "nomad_bucket" {
  compartment_id = var.compartment_id
  namespace      = var.namespace
  name           = var.bucket_name
  access_type    = "NoPublicAccess"

  storage_tier = "Standard"

  freeform_tags = {
    "Project" = "NomadCluster"
  }
}
