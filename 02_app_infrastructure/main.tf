# Enable necessary APIs
resource "google_project_service" "app_apis" {
  for_each = toset([
    "run.googleapis.com",
    "bigquery.googleapis.com",
    "cloudscheduler.googleapis.com",
    "monitoring.googleapis.com"
  ])
  service = each.key
  disable_on_destroy = false
}

# BigQuery Dataset - Depends on BQ API
resource "google_bigquery_dataset" "bnr_dataset" {
  depends_on = [google_project_service.app_apis]
  dataset_id = "bnr_data"
  location   = var.region
}

# BigQuery Table
resource "google_bigquery_table" "bnr_rates" {
  dataset_id = google_bigquery_dataset.bnr_dataset.dataset_id
  table_id   = "bnr_rates"

  schema = <<EOF
[
  {
    "name": "date",
    "type": "DATE",
    "mode": "REQUIRED"
  },
  {
    "name": "currency",
    "type": "STRING",
    "mode": "REQUIRED"
  },
  {
    "name": "value",
    "type": "FLOAT",
    "mode": "REQUIRED"
  },
  {
    "name": "multiplier",
    "type": "INTEGER",
    "mode": "REQUIRED"
  },
  {
    "name": "ingested_at",
    "type": "TIMESTAMP",
    "mode": "REQUIRED"
  }
]
EOF
}

# Cloud Run Job - Depends on Run API
resource "google_cloud_run_v2_job" "bnr_job" {
  depends_on = [google_project_service.app_apis]
  name       = "bnr-data-import"
  location   = var.region

  template {
    template {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/bnr-import-repo/bnr-import:${var.image_tag}"
        env {
          name  = "TABLE_ID"
          value = "${var.project_id}.bnr_data.bnr_rates"
        }
      }
    }
  }
}

# Cloud Scheduler Job
resource "google_cloud_scheduler_job" "daily_trigger" {
  depends_on  = [google_project_service.app_apis]
  name        = "bnr-daily-import"
  description = "Trigger daily BNR data import"
  schedule    = "30 13 * * 1-5" # 13:30 Bucharest time, Monday to Friday
  time_zone   = "Europe/Bucharest"
  region      = var.region

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.bnr_job.name}:run"
    
    oauth_token {
      service_account_email = google_service_account.scheduler_sa.email
    }
  }
}

# Service Account for Scheduler
resource "google_service_account" "scheduler_sa" {
  account_id   = "bnr-scheduler-sa"
  display_name = "Scheduler Service Account for BNR Import"
}

# IAM Binding to allow Scheduler to run the job
resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  location = google_cloud_run_v2_job.bnr_job.location
  name     = google_cloud_run_v2_job.bnr_job.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_sa.email}"
}