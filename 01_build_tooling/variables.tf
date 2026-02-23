variable "project_id" {
  type        = string
  description = "Google Cloud project ID"
}

variable "region" {
  type        = string
  default     = "europe-west3"
  description = "GCP region for resources"
}
