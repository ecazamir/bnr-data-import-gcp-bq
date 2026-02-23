output "repository_uri" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.bnr_repo.repository_id}"
  description = "Registry URI for Cloud Build configuration"
}

output "repo_name" {
  value = google_artifact_registry_repository.bnr_repo.repository_id
}
