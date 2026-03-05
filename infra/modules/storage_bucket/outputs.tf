output "bucket_name" {
  description = "The GCS bucket name"
  value       = google_storage_bucket.main.name
}

output "bucket_url" {
  description = "gs:// URL for the bucket"
  value       = "gs://${google_storage_bucket.main.name}"
}
