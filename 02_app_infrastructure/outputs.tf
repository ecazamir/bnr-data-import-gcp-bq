output "job_name" {
  value       = google_cloud_run_v2_job.bnr_job.name
  description = "Cloud Run Job Name"
}

output "bigquery_table_id" {
  value       = google_bigquery_table.bnr_rates.id
  description = "Final BQ Table ID"
}

output "scheduler_job_id" {
  value = google_cloud_scheduler_job.daily_trigger.id
}
