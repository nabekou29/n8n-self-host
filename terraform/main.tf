# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "cloudscheduler.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
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
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.n8n_runner.email}"
}

resource "google_storage_bucket_iam_member" "n8n_runner_backups" {
  bucket = google_storage_bucket.n8n_backups.name
  role   = "roles/storage.objectAdmin"
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
    max_instance_request_concurrency = 10

    containers {
      image = "n8nio/n8n:latest"

      resources {
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }

        cpu_idle          = true
        startup_cpu_boost = true
      }

      volume_mounts {
        name       = "n8n-data"
        mount_path = "/home/node/.n8n"
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
        name  = "N8N_HOST"
        value = var.custom_domain != "" ? var.custom_domain : "${var.service_name}-${var.project_id}.${var.region}.run.app"
      }

      env {
        name  = "N8N_PROTOCOL"
        value = "https"
      }

      env {
        name  = "WEBHOOK_URL"
        value = var.custom_domain != "" ? "https://${var.custom_domain}/" : "https://${var.service_name}-${var.project_id}.${var.region}.run.app/"
      }

      env {
        name  = "N8N_LOG_LEVEL"
        value = "info"
      }

      env {
        name  = "EXECUTIONS_DATA_SAVE_ON_ERROR"
        value = "none"
      }

      env {
        name  = "EXECUTIONS_DATA_SAVE_ON_SUCCESS"
        value = "none"
      }

      env {
        name  = "EXECUTIONS_DATA_SAVE_ON_PROGRESS"
        value = "false"
      }

      env {
        name  = "N8N_METRICS"
        value = "false"
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

      env {
        name  = "N8N_PROXY_HOPS"
        value = "1"
      }

      env {
        name  = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }

      ports {
        container_port = 5678
        name           = "http1"
      }


      startup_probe {
        http_get {
          path = "/healthz/"
          port = 5678
        }
        initial_delay_seconds = 10
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 5
      }

      liveness_probe {
        http_get {
          path = "/healthz/"
          port = 5678
        }
        initial_delay_seconds = 60
        timeout_seconds       = 5
        period_seconds        = 30
        failure_threshold     = 3
      }
    }

    volumes {
      name = "n8n-data"
      gcs {
        bucket    = google_storage_bucket.n8n_data.name
        read_only = false
      }
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

# Domain mapping for custom domain
resource "google_cloud_run_domain_mapping" "n8n_domain" {
  count    = var.custom_domain != "" ? 1 : 0
  name     = var.custom_domain
  location = var.region

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.n8n.name
  }

  depends_on = [google_cloud_run_v2_service.n8n]
}

# Cloud Scheduler to warm up instances before schedule triggers
resource "google_cloud_scheduler_job" "n8n_warmup" {
  name             = "n8n-instance-warmup"
  description      = "Warm up n8n instance before scheduled workflows"
  schedule         = "55 8-20 * * *" # Every hour at 55 minutes
  time_zone        = "Asia/Tokyo"
  attempt_deadline = "30s"

  retry_config {
    retry_count = 0
  }

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_v2_service.n8n.uri}/healthz/"

    headers = {
      "User-Agent" = "Google-Cloud-Scheduler"
    }
  }

  depends_on = [
    google_cloud_run_v2_service.n8n,
    google_project_service.required_apis
  ]
}
