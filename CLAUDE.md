# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains infrastructure code for self-hosting n8n workflow automation on Google Cloud Run using SQLite database with a custom Docker image that handles GCS synchronization. The setup uses Terraform for infrastructure management and Cloud Build for deployment.

## Current Architecture

```
Cloud Run (n8n) ←→ SQLite on GCS FUSE Volume
```

- **GCS FUSE Volume**: Cloud Run's built-in volume mount for persistence
- **SQLite Database**: Stored directly on GCS through FUSE mount
- **Simple Setup**: No custom Docker image needed

## Important Commands

### Initial Setup and Deployment

```bash
# 1. Initialize Terraform (from terraform directory)
cd terraform
terraform init

# 2. Create infrastructure and deploy n8n
terraform apply
```

### Access Information

```bash
cd terraform

# Get service URL
terraform output service_url

# Get credentials
terraform output -json n8n_credentials

# Get encryption key (store securely)
terraform output -raw encryption_key
```

### Backup Operations

```bash
# Manual backup of database
gsutil cp gs://${PROJECT_ID}-n8n-data/database.sqlite ./backup-$(date +%Y%m%d-%H%M%S).sqlite

# Check database file
gsutil ls -l gs://${PROJECT_ID}-n8n-data/
```

### Updates and Redeployment

```bash
# Update via Terraform
cd terraform
terraform apply
```

## Architecture Details

The project consists of:

1. **Cloud Run Service**: Hosts n8n application with concurrency=10
2. **Cloud Storage**: Two buckets - one for database, one for backups
3. **Official n8n Image**: Uses n8nio/n8n:latest
4. **Terraform**: Manages all infrastructure
5. **GCS FUSE**: Provides persistent volume for SQLite

## Volume Mount Configuration

- SQLite database is stored at `/home/node/.n8n/database.sqlite`
- GCS bucket is mounted as a volume at `/home/node/.n8n`
- Data persists automatically through Cloud Run's GCS FUSE integration

## Directory Structure

```
.
├── README.md              # Main documentation
├── CLAUDE.md             # This file
└── terraform/
    ├── main.tf           # Resource definitions
    ├── variables.tf      # Variable definitions
    ├── outputs.tf        # Output values
    └── backend.tf        # State backend config
```

## Development Workflow

1. **Infrastructure Changes**:

   - Modify Terraform files
   - Run `terraform plan` then `terraform apply`

2. **Configuration Updates**:
   - Update environment variables in `terraform/main.tf`
   - Run `terraform apply`

## Code Quality Checks

Always run these checks before applying changes:

```bash
# Format Terraform files
cd terraform && terraform fmt

# Validate Terraform configuration
cd terraform && terraform validate

# Security scan with Trivy
cd terraform && trivy config .
```

## Known Issues and Limitations

1. **429 Errors**:

   - May occur due to GCS FUSE rate limits
   - Consider increasing Cloud Run concurrency if needed

2. **Data Persistence**:

   - Data persists automatically through GCS FUSE
   - No data loss on container restart

3. **Scalability**:
   - Limited to single instance due to SQLite
   - Consider PostgreSQL for production

## Troubleshooting

### Check service logs

```bash
gcloud run services logs read n8n --region=us-central1 --limit=50
```

### Verify GCS bucket contents

```bash
gsutil ls -la gs://${PROJECT_ID}-n8n-data/
```

### Force container restart

```bash
gcloud run services update n8n --region=us-central1 --update-env-vars=FORCE_RESTART=$(date +%s)
```

## Future Improvements

1. **Migrate to Cloud SQL for production scale**
2. **Add monitoring and alerting**
3. **Implement automated backups to separate bucket**
4. **Add custom domain configuration**

## Cost Optimization

Current setup costs approximately:

- Cloud Run: $0-50/month (depends on usage)
- Cloud Storage: <$1/month
- Total: **<$51/month**

For production, add Cloud SQL:

- db-f1-micro: +$10/month
- db-g1-small: +$50/month (recommended)

