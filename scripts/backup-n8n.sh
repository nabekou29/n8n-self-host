#!/bin/bash
set -euo pipefail

# Manual backup script for n8n SQLite database
# Note: With the new architecture, automatic backups occur:
# - On container shutdown (via SIGTERM trap)
# - Every 5 minutes (periodic backup)
# This script can be used for additional manual backups

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
echo "Creating backup..."
gsutil -q cp gs://${BUCKET_NAME}/database.sqlite \
  gs://${BACKUP_BUCKET}/backups/database-${DATE}.sqlite || {
    echo "Failed to create backup"
    exit 1
}

# Verify backup
gsutil ls -l gs://${BACKUP_BUCKET}/backups/database-${DATE}.sqlite

# List successful backups
echo "Recent backups:"
gsutil ls -l gs://${BACKUP_BUCKET}/backups/ | tail -5

# Note: Lifecycle rules in Terraform will handle cleanup automatically

# Optional: Run VACUUM on local copy to check database integrity
echo "Downloading database for integrity check..."
TEMP_DB="/tmp/n8n-db-check-${DATE}.sqlite"
gsutil cp gs://${BACKUP_BUCKET}/backups/database-${DATE}.sqlite "${TEMP_DB}"

if sqlite3 "${TEMP_DB}" "PRAGMA integrity_check;" | grep -q "ok"; then
  echo "✓ Database integrity check passed"
else
  echo "✗ Database integrity check failed!"
  exit 1
fi

rm -f "${TEMP_DB}"

echo "Backup completed successfully!"