#!/bin/bash
set -e

# 環境変数
BUCKET_NAME="${GCS_BUCKET_NAME}"
DB_PATH="/home/node/.n8n/database.sqlite"
DB_DIR="/home/node/.n8n"

# ディレクトリ作成
mkdir -p "${DB_DIR}"

# 起動時：GCSからデータベースを復元
echo "[$(date)] Starting database restoration from GCS..."
if gsutil -q cp "gs://${BUCKET_NAME}/database.sqlite" "${DB_PATH}" 2>/dev/null; then
    echo "[$(date)] Database restored successfully from GCS"
else
    echo "[$(date)] No existing database found in GCS, starting with fresh database"
fi

# 終了シグナルのトラップ
backup_database() {
    echo "[$(date)] SIGTERM received, starting database backup..."
    
    # メインのバックアップ
    if [ -f "${DB_PATH}" ]; then
        echo "[$(date)] Backing up database to GCS..."
        gsutil -q cp "${DB_PATH}" "gs://${BUCKET_NAME}/database.sqlite"
        
        # タイムスタンプ付きバックアップも作成
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        gsutil -q cp "${DB_PATH}" "gs://${BUCKET_NAME}/backup/database-${TIMESTAMP}.sqlite"
        
        echo "[$(date)] Backup completed successfully"
    else
        echo "[$(date)] No database file found to backup"
    fi
    
    # 定期バックアッププロセスを停止
    if [ -n "${BACKUP_PID}" ]; then
        kill ${BACKUP_PID} 2>/dev/null || true
    fi
}
trap 'backup_database; exit 0' SIGTERM SIGINT

# 定期バックアップ（5分ごと）
(
    while true; do
        sleep 300
        if [ -f "${DB_PATH}" ]; then
            echo "[$(date)] Performing periodic backup..."
            gsutil -q cp "${DB_PATH}" "gs://${BUCKET_NAME}/periodic/database-latest.sqlite" 2>/dev/null || echo "[$(date)] Periodic backup failed"
        fi
    done
) &
BACKUP_PID=$!

# n8nを起動
echo "[$(date)] Starting n8n..."
exec n8n