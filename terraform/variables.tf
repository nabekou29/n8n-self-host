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


variable "n8n_encryption_key" {
  description = "N8N encryption key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "custom_domain" {
  description = "Custom domain for n8n (e.g., n8n.example.com)"
  type        = string
  default     = "n8n.nabekou29.com"
}

