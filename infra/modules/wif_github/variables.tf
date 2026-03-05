variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in owner/repo format (e.g. MNohava1987/drift-command)"
}

variable "service_account_email" {
  type        = string
  description = "Service account email that GitHub Actions will impersonate via WIF"
}

variable "pool_id" {
  type        = string
  default     = "github-actions-pool"
  description = "Workload Identity Pool ID"
}

variable "provider_id" {
  type        = string
  default     = "github-actions-provider"
  description = "Workload Identity Pool Provider ID"
}

variable "allowed_branch" {
  type        = string
  default     = "refs/heads/main"
  description = "Only OIDC tokens from this git ref can authenticate. Set to empty string to allow any branch (not recommended)."
}
