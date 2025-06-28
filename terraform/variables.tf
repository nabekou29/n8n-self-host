variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "nabekou29"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "n8n"
}

variable "n8n_basic_auth_user" {
  description = "N8N basic auth username"
  type        = string
  default     = "admin"
}

variable "n8n_basic_auth_password" {
  description = "N8N basic auth password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "n8n_encryption_key" {
  description = "N8N encryption key"
  type        = string
  sensitive   = true
  default     = ""
}