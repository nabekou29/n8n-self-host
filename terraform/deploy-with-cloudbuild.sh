#!/bin/bash
set -euo pipefail

# Cloud Buildを使用してN8Nをデプロイし、ボリュームマウントを設定

echo "Deploying N8N with Cloud Build..."

# Get values from Terraform
PROJECT_ID=$(terraform output -raw project_id)
REGION=$(terraform output -raw region)
SERVICE_NAME=$(terraform output -raw service_name)
BUCKET_NAME=$(terraform output -raw bucket_name)
SERVICE_ACCOUNT=$(terraform output -raw service_account_email)
ENCRYPTION_KEY=$(terraform output -raw encryption_key)
BASIC_AUTH_USER="admin"
BASIC_AUTH_PASSWORD=$(terraform output -json n8n_credentials | jq -r .password)

# Submit build
gcloud builds submit --no-source \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --config=cloudbuild.yaml \
  --substitutions="\
_SERVICE_NAME=${SERVICE_NAME},\
_IMAGE=n8nio/n8n:latest,\
_REGION=${REGION},\
_PROJECT_ID=${PROJECT_ID},\
_SERVICE_ACCOUNT=${SERVICE_ACCOUNT},\
_BUCKET_NAME=${BUCKET_NAME},\
_ENCRYPTION_KEY=${ENCRYPTION_KEY},\
_BASIC_AUTH_USER=${BASIC_AUTH_USER},\
_BASIC_AUTH_PASSWORD=${BASIC_AUTH_PASSWORD}"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "URL: https://${SERVICE_NAME}-${PROJECT_ID}.${REGION}.run.app"
echo "Username: ${BASIC_AUTH_USER}"
echo "Password: ${BASIC_AUTH_PASSWORD}"