variable "project_id" { type = string }
variable "bucket_name" { type = string }
variable "location" {
  type    = string
  default = "US"
}
variable "public_read" {
  type    = bool
  default = false
}

resource "google_storage_bucket" "main" {
  project                     = var.project_id
  name                        = var.bucket_name
  location                    = var.location
  force_destroy               = false
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_member" "public_read" {
  count  = var.public_read ? 1 : 0
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

output "bucket_name" {
  value = google_storage_bucket.main.name
}

output "bucket_url" {
  value = "gs://${google_storage_bucket.main.name}"
}
