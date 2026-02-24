output "bucket_name" {
  value       = oci_objectstorage_bucket.nomad_bucket.name
  description = "Name of the created bucket"
}

output "bucket_namespace" {
  value       = oci_objectstorage_bucket.nomad_bucket.namespace
  description = "Namespace of the bucket"
}
