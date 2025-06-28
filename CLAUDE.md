# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains infrastructure code for self-hosting n8n workflow automation on Google Cloud Run using SQLite database with Cloud Storage for persistence. The setup uses Terraform for infrastructure management and Cloud Build for deployment.

## Important Commands

### Initial Setup and Deployment
```bash
# 1. Initialize Terraform (from terraform directory)
cd terraform
terraform init

# 2. Create infrastructure
terraform apply

# 3. Deploy n8n with Cloud Build (includes volume mount setup)
cd ..
./scripts/deploy-with-cloudbuild.sh
```

### Access Information
```bash
# Get service URL
terraform output service_url

# Get credentials
terraform output -json n8n_credentials

# Get encryption key (store securely)
terraform output -raw encryption_key
```

### Backup Operations
```bash
# Run backup (from project root)
./scripts/backup-n8n.sh
```

### Updates and Redeployment
```bash
# IMPORTANT: Always use Cloud Build for deployment
./scripts/deploy-with-cloudbuild.sh

# WARNING: Do NOT run 'terraform apply' after initial setup
# It will remove volume mount configuration
```

## Architecture

The project consists of:

1. **Cloud Run Service**: Hosts n8n application with strict concurrency=1 (SQLite limitation)
2. **Cloud Storage**: Two buckets - one for database persistence, one for backups
3. **Volume Mount**: Cloud Storage FUSE mounts the database bucket to /home/node/.n8n
4. **Terraform**: Manages infrastructure but cannot handle Gen2 volume mounts
5. **Cloud Build**: Handles deployment including volume mount configuration

## Critical Limitations

1. **SQLite + Cloud Storage Issues**:
   - No file locking support
   - 60-100x slower performance than local SQLite
   - Risk of data corruption
   - NOT suitable for production use

2. **Terraform Limitations**:
   - Cannot manage Cloud Run Gen2 volume mounts
   - Running `terraform apply` after initial setup removes volume configuration
   - Always use Cloud Build for deployments

3. **Concurrency Restrictions**:
   - Max concurrency set to 1 to prevent database corruption
   - Only one instance can run at a time

## Directory Structure

```
.
├── README.md               # Main documentation
├── guide.md               # Detailed implementation guide
├── scripts/
│   ├── deploy-with-cloudbuild.sh  # Primary deployment script
│   └── backup-n8n.sh             # Database backup script
└── terraform/
    ├── main.tf            # Resource definitions
    ├── variables.tf       # Variable definitions
    ├── outputs.tf         # Output values
    ├── backend.tf         # State backend config
    └── cloudbuild.yaml    # Cloud Build configuration
```

## Development Workflow

1. **Infrastructure Changes**: Modify Terraform files and run `terraform apply`
2. **Configuration Updates**: Use environment variables in cloudbuild.yaml
3. **Deployment**: Always use `./scripts/deploy-with-cloudbuild.sh`
4. **Testing**: Access the service URL with provided credentials

## Common Issues

1. **Volume Mount Missing**: Always deploy via Cloud Build, not Terraform
2. **Database Locked**: Ensure concurrency=1 and max-instances=1
3. **Performance Issues**: This is expected with Cloud Storage + SQLite
4. **Backup Failures**: Check Cloud Storage permissions and bucket existence