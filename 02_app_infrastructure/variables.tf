variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west3"
}

variable "admin_email" {
  type        = string
  description = "Email for monitoring alerts"
}

variable "image_tag" {
  type        = string
  description = "The specific image tag to deploy (e.g. latest or a commit SHA)"
  default     = "latest"
}
