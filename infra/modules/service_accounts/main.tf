# ──────────────────────────────────────────────────────────────────────────────
# GitHub Actions deploy service account
#
# Permission rationale (broad permissions required for Terraform self-management):
#   - artifactregistry.writer  : push container images
#   - run.developer            : deploy Cloud Run services
#   - iam.serviceAccountAdmin  : Terraform manages the SA resources in this module
#   - iam.serviceAccountUser   : Terraform can act-as SAs during deploy
#   - resourcemanager.projectIamAdmin : Terraform manages IAM bindings in this project
#   - iam.workloadIdentityPoolAdmin   : Terraform manages the WIF pool/provider
#   - storage.admin            : Terraform creates and configures GCS buckets
#
# Note: storage.objectAdmin is also granted at the bucket level in envs/dev/main.tf
# for the tfstate bucket specifically. The project-level storage.admin covers bucket
# creation; future tightening should replace it with bucket-level bindings once all
# buckets are known at bootstrap time.
# ──────────────────────────────────────────────────────────────────────────────
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

resource "google_project_iam_member" "github_actions_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_sa_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_wif_admin" {
  project = var.project_id
  role    = "roles/iam.workloadIdentityPoolAdmin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ──────────────────────────────────────────────────────────────────────────────
# admin-api runtime service account
# ──────────────────────────────────────────────────────────────────────────────
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

# ──────────────────────────────────────────────────────────────────────────────
# telemetry-api runtime service account
# ──────────────────────────────────────────────────────────────────────────────
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
