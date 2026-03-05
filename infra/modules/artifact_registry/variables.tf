variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "location" {
  type        = string
  default     = "us-central1"
  description = "Artifact Registry location"
}

variable "repository_id" {
  type        = string
  default     = "drift-command"
  description = "Artifact Registry repository ID"
}
