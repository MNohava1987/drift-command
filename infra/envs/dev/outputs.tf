output "artifact_registry_url" {
  description = "Docker push URL for the Artifact Registry repository"
  value       = module.artifact_registry.repository_url
}

output "workload_identity_provider" {
  description = "WIF provider resource name — set as GCP_WORKLOAD_IDENTITY_PROVIDER in GitHub secrets"
  value       = module.wif_github.workload_identity_provider
}
