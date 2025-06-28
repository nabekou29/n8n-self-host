output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "service_name" {
  description = "Cloud Run service name"
  value       = var.service_name
}

output "service_url" {
  description = "URL of the deployed n8n service"
  value       = google_cloud_run_v2_service.n8n.uri
}

output "n8n_credentials" {
  description = "N8N access credentials"
  value = {
    url      = google_cloud_run_v2_service.n8n.uri
    username = var.n8n_basic_auth_user
    password = var.n8n_basic_auth_password != "" ? var.n8n_basic_auth_password : random_password.n8n_basic_auth.result
  }
  sensitive = true
}

output "encryption_key" {
  description = "N8N encryption key (store this securely!)"
  value       = var.n8n_encryption_key != "" ? var.n8n_encryption_key : random_id.n8n_encryption_key.hex
  sensitive   = true
}

output "bucket_name" {
  description = "Name of the Cloud Storage bucket"
  value       = google_storage_bucket.n8n_data.name
}

output "backup_bucket_name" {
  description = "Name of the backup bucket"
  value       = google_storage_bucket.n8n_backups.name
}

output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.n8n_runner.email
}