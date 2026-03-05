variable "project_id" { type = string }

# GitHub Actions deployment service account
resource "google_service_account" "github_actions" {
  project      = var.project_id
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Deploy SA"
}

resource "google_project_iam_member" "github_actions_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_storage_creator" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# admin-api runtime service account
resource "google_service_account" "admin_api" {
  project      = var.project_id
  account_id   = "admin-api-sa"
  display_name = "Admin API Runtime SA"
}

resource "google_project_iam_member" "admin_api_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.admin_api.email}"
}

# telemetry-api runtime service account
resource "google_service_account" "telemetry_api" {
  project      = var.project_id
  account_id   = "telemetry-api-sa"
  display_name = "Telemetry API Runtime SA"
}

resource "google_project_iam_member" "telemetry_api_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.telemetry_api.email}"
}

output "github_actions_sa_email" {
  value = google_service_account.github_actions.email
}

output "admin_api_sa_email" {
  value = google_service_account.admin_api.email
}

output "telemetry_api_sa_email" {
  value = google_service_account.telemetry_api.email
}
