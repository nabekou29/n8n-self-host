# N8N Self-Host on Google Cloud Run

Cloud RunでN8Nをセルフホストするためのインフラストラクチャコード

## アーキテクチャ

このソリューションは、コスト最適化のためにSQLite + ローカルストレージ方式を採用しています：

- **起動時**: GCSからSQLiteデータベースを復元
- **実行中**: ローカルファイルシステムでSQLiteを使用（高速）
- **終了時**: SQLiteデータベースをGCSにバックアップ
- **定期バックアップ**: 5分ごとに自動バックアップ

### メリット
- 月額コストがほぼゼロ（GCSストレージのみ）
- GCS FUSEの429エラーを回避
- SQLiteの高速性を維持

### デメリット
- 予期しないクラッシュ時のデータロスリスク（最大5分）
- 起動時間がデータベースサイズに依存
- 大規模なデータベースには不向き

## 必要な環境

- Google Cloud アカウント
- Terraform >= 1.0
- gcloud CLI
- Docker
- 適切な権限（Project Editor以上）

## デプロイ手順

### 1. リポジトリのクローン

```bash
git clone https://github.com/nabekou29/n8n-self-host.git
cd n8n-self-host
```

### 2. GCPの準備

```bash
# ログイン
gcloud auth login

# プロジェクトの設定
export PROJECT_ID="your-project-id"
gcloud config set project ${PROJECT_ID}
```

### 3. Terraformでのインフラ構築

```bash
cd terraform

# 初期化
terraform init

# プランの確認
terraform plan

# インフラの作成
terraform apply
```

### 4. カスタムDockerイメージのデプロイ

```bash
# プロジェクトルートに戻る
cd ..

# Cloud Build経由でデプロイ
./scripts/deploy.sh
```

### 5. アクセス情報の取得

```bash
cd terraform

# サービスURL
terraform output service_url

# 認証情報（JSONフォーマット）
terraform output -json n8n_credentials

# 暗号化キー（必ず安全に保管）
terraform output -raw encryption_key
```

## 動作確認

1. 取得したURLにアクセス
2. Basic認証でログイン
3. 簡単なワークフローを作成して保存
4. Cloud Runのログでバックアップ処理を確認：

```bash
gcloud run services logs read n8n --region=us-central1 --limit=50
```

## データ管理

### 現在のデータベース
```bash
gsutil ls -l gs://${PROJECT_ID}-n8n-data/
```

### 定期バックアップ
```bash
gsutil ls -l gs://${PROJECT_ID}-n8n-data/periodic/
```

### タイムスタンプ付きバックアップ
```bash
gsutil ls -l gs://${PROJECT_ID}-n8n-data/backup/
```

### 手動バックアップ
```bash
./scripts/backup-n8n.sh
```

## トラブルシューティング

### 429エラーが発生する場合

Cloud Runサービスへの429エラーの場合：
```bash
# 並行処理数を増やす
gcloud run services update n8n --region=us-central1 --concurrency=10
```

### データベースが復元されない場合
```bash
# GCSバケットの内容を確認
gsutil ls -la gs://${PROJECT_ID}-n8n-data/
```

### ログの確認
```bash
# Cloud Runのログを確認
gcloud run services logs read n8n --region=us-central1 --limit=100
```

## メンテナンス

### イメージの更新
```bash
# n8nの新バージョンに更新
./scripts/deploy.sh
```

### データベースの最適化
```bash
# データベースをダウンロードして最適化
gsutil cp gs://${PROJECT_ID}-n8n-data/database.sqlite /tmp/
sqlite3 /tmp/database.sqlite "VACUUM;"
gsutil cp /tmp/database.sqlite gs://${PROJECT_ID}-n8n-data/
```

## 将来の移行パス

データ量が増えてきた場合は、Cloud SQL（PostgreSQL）への移行を検討してください：

1. n8nのエクスポート機能でワークフローをバックアップ
2. Cloud SQL インスタンスを作成
3. 環境変数を PostgreSQL 用に変更
4. ワークフローをインポート

## プロジェクト構成

```
.
├── docker/                 # カスタムDockerイメージ
│   ├── Dockerfile
│   └── docker-entrypoint.sh
├── scripts/               # デプロイ・管理スクリプト
│   ├── deploy.sh
│   └── backup-n8n.sh
├── terraform/             # インフラストラクチャ定義
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── cloudbuild.yaml        # Cloud Build設定
```

## クリーンアップ

```bash
cd terraform
terraform destroy
```

## ライセンス

MIT