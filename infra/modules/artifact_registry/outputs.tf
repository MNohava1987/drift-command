output "repository_url" {
  description = "Docker push URL: {location}-docker.pkg.dev/{project}/{repo}"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}
