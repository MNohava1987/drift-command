variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique GCS bucket name"
}

variable "location" {
  type        = string
  default     = "US"
  description = "GCS bucket location (multi-region US, EU, or single region e.g. us-central1)"
}

variable "public_read" {
  type        = bool
  default     = false
  description = "When true, grants allUsers the objectViewer role (use only for public config buckets)"
}
