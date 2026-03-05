variable "project_id" { type = string }
variable "github_repo" {
  type        = string
  description = "Format: owner/repo — e.g. MNohava1987/drift-command"
}
variable "service_account_email" { type = string }
variable "pool_id" {
  type    = string
  default = "github-actions-pool"
}
variable "provider_id" {
  type    = string
  default = "github-actions-provider"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "pool_name" {
  value = google_iam_workload_identity_pool.github.name
}
