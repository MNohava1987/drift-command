variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Default GCP region for all resources"
}

variable "github_repo" {
  type        = string
  default     = "MNohava1987/drift-command"
  description = "GitHub repository in owner/repo format used for WIF binding"
}
