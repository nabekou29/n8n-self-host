#!/bin/bash
set -e

# Get values from Terraform output
PROJECT_ID=$(terraform output -raw project_id 2>/dev/null || echo "nabekou29")
REGION=$(terraform output -raw region 2>/dev/null || echo "us-central1")
SERVICE_NAME=$(terraform output -raw service_name 2>/dev/null || echo "n8n")
BUCKET_NAME=$(terraform output -raw bucket_name)

echo "Updating Cloud Run service to mount Cloud Storage volume..."

# Update the service with Cloud Storage volume mount
gcloud beta run services update ${SERVICE_NAME} \
  --region ${REGION} \
  --execution-environment gen2 \
  --add-volume name=n8n-data,type=cloud-storage,bucket=${BUCKET_NAME},mount-options="metadata-cache-ttl-secs=300;stat-cache-max-size-mb=64;type-cache-max-size-mb=8" \
  --add-volume-mount volume=n8n-data,mount-path=/home/node/.n8n

echo "Cloud Storage volume mounted successfully!"
echo ""
echo "=== N8N Access Information ==="
echo "URL: $(terraform output -raw service_url)"
echo ""
echo "To get credentials, run:"
echo "terraform output -json n8n_credentials"
echo ""
echo "To get encryption key (store securely!), run:"
echo "terraform output -raw encryption_key"