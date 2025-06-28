#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting n8n deployment with custom Docker image...${NC}"

# Get project ID
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: No active GCP project. Please run 'gcloud config set project PROJECT_ID'${NC}"
    exit 1
fi

# Get region from Terraform or use default
if [ -f "terraform/terraform.tfvars" ]; then
    REGION=$(grep region terraform/terraform.tfvars | cut -d'"' -f2)
fi
REGION=${REGION:-us-central1}

echo -e "${YELLOW}Using project: ${PROJECT_ID}${NC}"
echo -e "${YELLOW}Using region: ${REGION}${NC}"

# Submit Cloud Build job
echo -e "${GREEN}Submitting Cloud Build job...${NC}"
gcloud builds submit \
    --config=cloudbuild.yaml \
    --substitutions=_REGION=${REGION} \
    .

echo -e "${GREEN}Deployment complete!${NC}"

# Get service URL
echo -e "${GREEN}Getting service URL...${NC}"
SERVICE_URL=$(gcloud run services describe n8n --region=${REGION} --format='value(status.url)')
echo -e "${GREEN}Service URL: ${SERVICE_URL}${NC}"

# Get credentials from Terraform
echo -e "${YELLOW}To get credentials, run:${NC}"
echo "cd terraform && terraform output -json n8n_credentials"