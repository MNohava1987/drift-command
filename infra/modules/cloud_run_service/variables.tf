variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "service_name" {
  type        = string
  description = "Name of the Cloud Run service"
}

variable "image" {
  type        = string
  description = "Container image URL (e.g. us-central1-docker.pkg.dev/PROJECT/repo/app:tag)"
}

variable "service_account_email" {
  type        = string
  description = "Service account email the Cloud Run service runs as"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP region for the Cloud Run service"
}
