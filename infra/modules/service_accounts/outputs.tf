output "github_actions_sa_email" {
  description = "Email of the GitHub Actions deploy service account"
  value       = google_service_account.github_actions.email
}

output "admin_api_sa_email" {
  description = "Email of the admin-api Cloud Run runtime service account"
  value       = google_service_account.admin_api.email
}

output "telemetry_api_sa_email" {
  description = "Email of the telemetry-api Cloud Run runtime service account"
  value       = google_service_account.telemetry_api.email
}
