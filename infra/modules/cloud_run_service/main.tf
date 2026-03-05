variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "service_name" {
  description = "Name of the Cloud Run service."
  type        = string
}

variable "image" {
  description = "Container image URL (e.g. us-docker.pkg.dev/PROJECT/repo/app:tag)."
  type        = string
}

variable "service_account_email" {
  description = "Service account email the Cloud Run service runs as."
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Run service."
  type        = string
  default     = "us-central1"
}

# ------------------------------------------------------------------
# Stub — not deployed in M0/M1. Reserved for future backend services.
# Uncomment and configure when a server-side component is needed.
# ------------------------------------------------------------------
# resource "google_cloud_run_v2_service" "this" {
#   project  = var.project_id
#   name     = var.service_name
#   location = var.region
#
#   template {
#     service_account = var.service_account_email
#     containers {
#       image = var.image
#     }
#   }
# }

output "service_url" {
  description = "Public URL of the Cloud Run service (empty until deployed)."
  value       = ""
}
