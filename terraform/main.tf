# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# Random password generation
resource "random_password" "n8n_basic_auth" {
  length  = 16
  special = true
}

resource "random_id" "n8n_encryption_key" {
  byte_length = 16
}

# Cloud Storage bucket for SQLite database
resource "google_storage_bucket" "n8n_data" {
  name     = "${var.project_id}-n8n-data"
  location = var.region

  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age            = 30
      matches_prefix = ["backups/"]
      with_state     = "ANY"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Cloud Storage bucket for backups
resource "google_storage_bucket" "n8n_backups" {
  name     = "${var.project_id}-n8n-backups"
  location = var.region

  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age        = 30
      with_state = "ANY"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Service account for Cloud Run
resource "google_service_account" "n8n_runner" {
  account_id   = "n8n-runner"
  display_name = "n8n Cloud Run Service Account"
  description  = "Service account for running n8n on Cloud Run"

  depends_on = [google_project_service.required_apis]
}

# IAM bindings for service account
resource "google_storage_bucket_iam_member" "n8n_runner_storage" {
  bucket = google_storage_bucket.n8n_data.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.n8n_runner.email}"
}

resource "google_storage_bucket_iam_member" "n8n_runner_backups" {
  bucket = google_storage_bucket.n8n_backups.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.n8n_runner.email}"
}

resource "google_project_iam_member" "n8n_runner_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.n8n_runner.email}"
}

# Cloud Run service
resource "google_cloud_run_v2_service" "n8n" {
  name     = var.service_name
  location = var.region

  template {
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    service_account       = google_service_account.n8n_runner.email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    timeout                          = "300s"
    max_instance_request_concurrency = 1

    # Volume configuration will be added via gcloud command after deployment
    # as Terraform doesn't yet support Cloud Storage volume mounts

    containers {
      image = "docker.n8n.io/n8nio/n8n:latest"

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }

        cpu_idle = true
      }

      env {
        name  = "DB_TYPE"
        value = "sqlite"
      }

      env {
        name  = "DB_SQLITE_DATABASE"
        value = "/home/node/.n8n/database.sqlite"
      }

      env {
        name  = "N8N_ENCRYPTION_KEY"
        value = var.n8n_encryption_key != "" ? var.n8n_encryption_key : random_id.n8n_encryption_key.hex
      }

      env {
        name  = "N8N_BASIC_AUTH_ACTIVE"
        value = "true"
      }

      env {
        name  = "N8N_BASIC_AUTH_USER"
        value = var.n8n_basic_auth_user
      }

      env {
        name  = "N8N_BASIC_AUTH_PASSWORD"
        value = var.n8n_basic_auth_password != "" ? var.n8n_basic_auth_password : random_password.n8n_basic_auth.result
      }

      env {
        name  = "N8N_HOST"
        value = "${var.service_name}-${var.project_id}.${var.region}.run.app"
      }

      env {
        name  = "N8N_PROTOCOL"
        value = "https"
      }

      env {
        name  = "WEBHOOK_URL"
        value = "https://${var.service_name}-${var.project_id}.${var.region}.run.app/"
      }

      env {
        name  = "N8N_LOG_LEVEL"
        value = "warn"
      }

      env {
        name  = "N8N_DIAGNOSTICS_ENABLED"
        value = "false"
      }

      env {
        name  = "N8N_PERSONALIZATION_ENABLED"
        value = "false"
      }

      env {
        name  = "GENERIC_TIMEZONE"
        value = "Asia/Tokyo"
      }

      env {
        name  = "NODE_OPTIONS"
        value = "--max-old-space-size=960"
      }

      # Volume mount will be configured via gcloud command after deployment
    }
  }

  depends_on = [
    google_project_service.required_apis,
    google_service_account.n8n_runner,
  ]
}

# IAM policy to allow unauthenticated access
resource "google_cloud_run_service_iam_member" "n8n_public" {
  service  = google_cloud_run_v2_service.n8n.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}