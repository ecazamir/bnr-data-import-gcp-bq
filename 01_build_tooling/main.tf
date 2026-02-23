# Enable necessary APIs
resource "google_project_service" "build_apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

# Repository - Depends on Registry API
resource "google_artifact_registry_repository" "bnr_repo" {
  depends_on    = [google_project_service.build_apis]
  location      = var.region
  repository_id = "bnr-import-repo"
  format        = "DOCKER"
}

# Cloud Build permissions - Depends on IAM API
data "google_project" "project" {}

resource "google_project_iam_member" "cloudbuild_perms" {
  depends_on = [google_project_service.build_apis]
  for_each   = toset(["roles/run.admin", "roles/iam.serviceAccountUser", "roles/artifactregistry.writer"])
  project    = var.project_id
  role       = each.key
  member     = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Bucket for Terraform State
resource "google_storage_bucket" "terraform_state" {
  depends_on    = [google_project_service.build_apis]
  name          = "${var.project_id}-tfstate"
  location      = var.region
  force_destroy = false
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}
