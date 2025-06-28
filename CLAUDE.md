# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains infrastructure code for self-hosting n8n workflow automation on Google Cloud Run using SQLite database with a custom Docker image that handles GCS synchronization. The setup uses Terraform for infrastructure management and Cloud Build for deployment.

## Current Architecture

```
Cloud Run (n8n) ←→ Local SQLite ←→ GCS Backup
```

- **No GCS FUSE**: Avoids 429 rate limit errors
- **Local SQLite**: Runs in container memory for performance
- **GCS Sync**: Backup/restore on startup/shutdown + periodic backups

## Important Commands

### Initial Setup and Deployment
```bash
# 1. Initialize Terraform (from terraform directory)
cd terraform
terraform init

# 2. Create infrastructure
terraform apply

# 3. Deploy n8n with Cloud Build
cd ..
./scripts/deploy.sh
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
# Run manual backup (from project root)
./scripts/backup-n8n.sh

# Check automatic backups
gsutil ls gs://${PROJECT_ID}-n8n-data/periodic/
gsutil ls gs://${PROJECT_ID}-n8n-data/backup/
```

### Updates and Redeployment
```bash
# Deploy updates via Cloud Build
./scripts/deploy.sh
```

## Architecture Details

The project consists of:

1. **Cloud Run Service**: Hosts n8n application with concurrency=10
2. **Cloud Storage**: Two buckets - one for database/backups, one for state
3. **Custom Docker Image**: Handles database sync with GCS
4. **Terraform**: Manages all infrastructure including Artifact Registry
5. **Cloud Build**: Builds and deploys the custom Docker image

## Custom Docker Implementation

### Entrypoint Script Flow
1. **Startup**: Download database.sqlite from GCS (if exists)
2. **Runtime**: SQLite runs locally in container
3. **Periodic**: Backup to GCS every 5 minutes
4. **Shutdown**: Upload database.sqlite to GCS on SIGTERM

### Current Issues
- Custom entrypoint may not be executing properly
- Need to investigate n8n's default entrypoint integration

## Directory Structure

```
.
├── README.md              # Main documentation
├── guide.md              # Detailed implementation guide
├── CLAUDE.md             # This file
├── cloudbuild.yaml       # Cloud Build configuration
├── docker/
│   ├── Dockerfile        # Custom n8n image
│   └── docker-entrypoint.sh  # Sync script
├── scripts/
│   ├── deploy.sh         # Deployment script
│   └── backup-n8n.sh     # Manual backup script
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

2. **Docker Image Changes**:
   - Modify files in `docker/` directory
   - Deploy via `./scripts/deploy.sh`

3. **Configuration Updates**: 
   - Update environment variables in `terraform/main.tf`
   - Run `terraform apply` then `./scripts/deploy.sh`

## Known Issues and Limitations

1. **429 Errors**: 
   - GCS FUSE removed but seeing some 429s
   - May be Cloud Run service limits

2. **Data Persistence**:
   - Max 5 minute data loss on crash
   - Startup time increases with database size

3. **Scalability**:
   - Limited to single instance due to SQLite
   - Consider PostgreSQL for production

## Troubleshooting

### Check if custom entrypoint is running
```bash
gcloud run services logs read n8n --region=us-central1 --limit=50 | grep -E "Starting database|Backing up"
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

1. **Fix custom entrypoint execution**
2. **Migrate to Cloud SQL for production**
3. **Add monitoring and alerting**
4. **Implement proper health checks**

## Cost Optimization

Current setup costs approximately:
- Cloud Run: $0-50/month (depends on usage)
- Cloud Storage: <$1/month
- Total: **<$51/month**

For production, add Cloud SQL:
- db-f1-micro: +$10/month
- db-g1-small: +$50/month (recommended)