# n8n on Cloud Run - 実装ガイド

## アーキテクチャ概要

このプロジェクトは、Google Cloud Run上でn8nを動作させるための最適化された実装です。

### 現在の実装方式：SQLite + GCS同期

```
┌─────────────────┐
│   Cloud Run     │
│     (n8n)       │
│ SQLite (local)  │
└────────┬────────┘
         │ 起動時復元
         │ 終了時バックアップ
         │ 5分ごと定期バックアップ
┌────────▼────────┐
│ Cloud Storage   │
│  (GCS Bucket)   │
└─────────────────┘
```

#### 動作フロー

1. **コンテナ起動時**
   - GCSからdatabase.sqliteをダウンロード
   - /home/node/.n8n/に配置

2. **通常運用中**
   - SQLiteはローカルファイルシステムで動作
   - 5分ごとにGCSへ自動バックアップ

3. **コンテナ終了時**
   - SIGTERMシグナルをトラップ
   - database.sqliteをGCSへアップロード

## なぜこの方式を選んだか

### 以前の問題：GCS FUSE

最初は、GCS FUSEを使用してCloud Storageをボリュームマウントしていましたが、以下の問題が発生しました：

- **429 Too Many Requests エラー**の頻発
- SQLiteの頻繁なファイルI/OがGCSのレート制限に引っかかる
- 60-100倍のパフォーマンス低下
- ファイルロックが機能しない

### 現在の方式のメリット

- GCS FUSEを使用しないため429エラーなし
- SQLiteの高速性を維持
- 月額コストがほぼゼロ（GCSストレージのみ）
- シンプルな実装

### デメリットと対策

- **予期しないクラッシュ時のデータロス**
  - 対策：5分ごとの定期バックアップで最大5分のロスに抑制
- **起動時間の増加**
  - データベースサイズに比例（100MB以上は注意）
- **スケーラビリティの制限**
  - SQLiteの制約により最大インスタンス数は1

## Terraform実装の詳細

### 主要リソース

```hcl
# Artifact Registry（カスタムDockerイメージ用）
resource "google_artifact_registry_repository" "n8n_repo" {
  repository_id = "n8n"
  location      = var.region
  format        = "DOCKER"
}

# Cloud Runサービス
resource "google_cloud_run_v2_service" "n8n" {
  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/n8n/n8n:latest"
      
      env {
        name  = "GCS_BUCKET_NAME"
        value = google_storage_bucket.n8n_data.name
      }
    }
  }
}
```

### 重要な設定

- `max_instance_count = 1`：SQLiteの同時書き込み制限
- `containerConcurrency = 10`：429エラー対策（1から増加）

## Docker実装の詳細

### カスタムエントリーポイント（docker-entrypoint.sh）

```bash
#!/bin/bash
set -e

# 環境変数
BUCKET_NAME="${GCS_BUCKET_NAME}"
DB_PATH="/home/node/.n8n/database.sqlite"

# 起動時：GCSから復元
echo "[$(date)] Starting database restoration from GCS..."
gsutil -q cp "gs://${BUCKET_NAME}/database.sqlite" "${DB_PATH}" 2>/dev/null || \
  echo "[$(date)] No existing database found, starting fresh"

# 終了時：GCSへバックアップ
backup_database() {
    echo "[$(date)] Backing up database to GCS..."
    gsutil -q cp "${DB_PATH}" "gs://${BUCKET_NAME}/database.sqlite"
    gsutil -q cp "${DB_PATH}" "gs://${BUCKET_NAME}/backup/database-$(date +%Y%m%d-%H%M%S).sqlite"
}
trap 'backup_database; exit 0' SIGTERM SIGINT

# 定期バックアップ（5分ごと）
(
    while true; do
        sleep 300
        if [ -f "${DB_PATH}" ]; then
            gsutil -q cp "${DB_PATH}" "gs://${BUCKET_NAME}/periodic/database-latest.sqlite" &
        fi
    done
) &

# n8nを起動
exec n8n
```

## トラブルシューティング

### カスタムエントリーポイントが動作しない場合

現在の実装では、カスタムエントリーポイントが正しく実行されていない可能性があります。原因として：

1. n8nの公式イメージが独自のエントリーポイントを持っている
2. 実行権限の問題
3. bashがインストールされていない

対策：
- Dockerfileでrootユーザーに切り替えてパッケージをインストール
- 実行権限を確実に付与
- n8nのデフォルトエントリーポイントとの統合を検討

### 429エラーが発生する場合

現在、2種類の429エラーが確認されています：

1. **GCS関連の429エラー**
   - カスタムエントリーポイントが動作していない可能性
   - GCSへの直接アクセスが発生している

2. **Cloud Runサービスへの429エラー**
   - 並行処理数の設定を調整
   - Cloud Runの無料枠制限の可能性

## 将来の改善案

### 1. Cloud SQL（PostgreSQL）への移行

最も推奨される本番環境向けソリューション：

```
┌─────────────────┐
│   Cloud Run     │
│     (n8n)       │
│   Min: 0-10     │
└────────┬────────┘
         │ プライベート接続
┌────────▼────────┐
│   Cloud SQL     │
│  (PostgreSQL)   │
└─────────────────┘
```

**メリット**
- 5-10倍の同時実行性能
- トランザクション処理
- 自動バックアップ
- 高可用性

**コスト**
- db-f1-micro: 約$10/月
- db-g1-small: 約$50/月（本番推奨）

### 2. Firestore/Datastore

NoSQLオプション：
- サーバーレスで自動スケール
- 使用量ベースの課金
- n8nのサポート状況要確認

### 3. 外部データベースサービス

- Supabase
- Neon
- PlanetScale

## パフォーマンスチューニング

### SQLite最適化

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -64000;
PRAGMA temp_store = MEMORY;
```

### Cloud Runの設定

- CPU: 1 vCPU（最小）
- メモリ: 1Gi（推奨）
- タイムアウト: 300秒

## セキュリティ考慮事項

1. **暗号化キー**
   - N8N_ENCRYPTION_KEYは必ず安全に管理
   - Terraformステートにも含まれるため注意

2. **アクセス制御**
   - Basic認証を有効化
   - Cloud IAPの利用も検討

3. **バックアップ**
   - GCSのバージョニング有効化
   - 定期的な外部バックアップ

## まとめ

このソリューションは、コストを最小限に抑えつつn8nを運用するための実用的なアプローチです。ただし、以下の点に注意してください：

### ✅ 適している用途
- 個人の学習・実験環境
- 小規模な自動化タスク
- コスト重視の環境

### ⚠️ 適さない用途
- 本番環境での重要なワークフロー
- 高頻度実行（1日100回以上）
- 複数ユーザーでの共有利用

本番環境や大規模利用には、Cloud SQLへの移行を強く推奨します。