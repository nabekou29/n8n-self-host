#!/bin/bash
set -e

# Navigate to terraform directory to get outputs
TERRAFORM_DIR="$(dirname "$0")/../terraform"
cd "$TERRAFORM_DIR"

# Get values from Terraform output
PROJECT_ID=$(terraform output -raw project_id)
REGION=$(terraform output -raw region)
BUCKET_NAME=$(terraform output -raw bucket_name)
BACKUP_BUCKET=$(terraform output -raw backup_bucket_name)
DATE=$(date +%Y%m%d-%H%M%S)

echo "Starting backup at ${DATE}"
echo "Source bucket: ${BUCKET_NAME}"
echo "Backup bucket: ${BACKUP_BUCKET}"

# Create backup of SQLite database
gsutil cp gs://${BUCKET_NAME}/database.sqlite \
  gs://${BACKUP_BUCKET}/backups/database-${DATE}.sqlite

# Verify backup
gsutil ls -l gs://${BACKUP_BUCKET}/backups/database-${DATE}.sqlite

# Clean up old backups (older than 30 days)
echo "Cleaning up old backups..."
gsutil ls gs://${BACKUP_BUCKET}/backups/ | \
  while read backup; do
    backup_date=$(echo $backup | grep -oP '\d{8}' | head -1)
    if [ ! -z "$backup_date" ]; then
      days_old=$(( ($(date +%s) - $(date -d $backup_date +%s 2>/dev/null || echo 0)) / 86400 ))
      if [ $days_old -gt 30 ]; then
        echo "Deleting old backup: $backup"
        gsutil rm $backup
      fi
    fi
  done

echo "Backup completed successfully!"