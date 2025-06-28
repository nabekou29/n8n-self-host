#!/bin/bash
set -euo pipefail

# Cloud Schedulerを使用してバックアップジョブをスケジュール
# 注意: Cloud Run Jobsを使用するため、追加のセットアップが必要

TERRAFORM_DIR="$(dirname "$0")/../terraform"
cd "$TERRAFORM_DIR"

PROJECT_ID=$(terraform output -raw project_id)
REGION=$(terraform output -raw region)

echo "Setting up automated backup schedule for project: ${PROJECT_ID}"

# Enable required APIs
echo "Enabling Cloud Scheduler API..."
gcloud services enable cloudscheduler.googleapis.com --project="${PROJECT_ID}"

# Create Cloud Scheduler job (runs daily at 3 AM JST)
echo "Creating Cloud Scheduler job..."
gcloud scheduler jobs create http n8n-backup \
  --location="${REGION}" \
  --schedule="0 3 * * *" \
  --time-zone="Asia/Tokyo" \
  --uri="https://console.cloud.google.com" \
  --http-method=GET \
  --description="Daily backup of N8N SQLite database" \
  --project="${PROJECT_ID}" || echo "Scheduler job already exists"

echo ""
echo "⚠️  Note: This sets up the schedule, but you need to:"
echo "1. Create a Cloud Run Job or Cloud Function to execute the backup"
echo "2. Update the scheduler job to point to the correct endpoint"
echo "3. Configure authentication for the job"
echo ""
echo "Alternative: Use cron on a persistent VM or your local machine"