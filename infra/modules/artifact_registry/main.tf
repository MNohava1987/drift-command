variable "project_id" { type = string }
variable "location" {
  type    = string
  default = "us-central1"
}
variable "repository_id" {
  type    = string
  default = "drift-command"
}

resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  format        = "DOCKER"
  description   = "Drift Command container images"
}

output "repository_url" {
  value = "${var.location}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}
