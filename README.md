# n8n Self-Host on Google Cloud Run

Cloud Runでn8nをセルフホストするためのインフラストラクチャコード

## アーキテクチャ

このソリューションは、Cloud Run上で公式n8nイメージを使用し、SQLiteデータベースをGCS FUSEボリュームで永続化しています：

- **データベース**: SQLiteをGCS上に保存
- **永続化**: Cloud RunのGCS FUSEボリュームマウント機能を使用
- **コスト**: ほぼゼロ（GCSストレージのみ）

### メリット

- 月額コストがほぼゼロ（GCSストレージのみ）
- 設定がシンプル
- 自動的にデータが永続化される

### デメリット

- GCS FUSEのパフォーマンス制限
- 大規模なデータベースには不向き
- 429エラーが発生する可能性

## 必要な環境

- Google Cloud アカウント
- Terraform >= 1.0
- gcloud CLI
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

### 4. サービスの確認

Terraform applyが完了すると、n8nサービスが自動的にデプロイされます。

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
# データベースファイルを直接コピー
gsutil cp gs://${PROJECT_ID}-n8n-data/database.sqlite ./backup-$(date +%Y%m%d-%H%M%S).sqlite
```

## メンテナンス

### イメージの更新

```bash
# Terraformでイメージを更新
cd terraform
terraform apply -var="n8n_image_tag=latest"
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
├── terraform/             # インフラストラクチャ定義
│   ├── main.tf           # メインのリソース定義
│   ├── variables.tf      # 変数定義
│   ├── outputs.tf        # 出力定義
│   └── backend.tf        # Terraformステート設定
├── README.md             # このファイル
└── CLAUDE.md             # Claude Code用ガイドライン
```

## クリーンアップ

```bash
cd terraform
terraform destroy
```

