# ──────────────────────────────────────────────────────────────────────────────
# Stub — not deployed until backend services are needed (M6+).
# Uncomment and configure when a Cloud Run service is ready to deploy.
# ──────────────────────────────────────────────────────────────────────────────

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
