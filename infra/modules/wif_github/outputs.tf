output "workload_identity_provider" {
  description = "Full WIF provider resource name — use as GCP_WORKLOAD_IDENTITY_PROVIDER in GitHub secrets"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "pool_name" {
  description = "Full WIF pool resource name"
  value       = google_iam_workload_identity_pool.github.name
}
