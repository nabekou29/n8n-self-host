# N8N on Cloud Run - Terraform Configuration

このディレクトリには、Cloud RunでN8NをデプロイするためのTerraform設定が含まれています。

## 前提条件

- Terraform >= 1.0
- Google Cloud SDK (gcloud)
- 適切な権限を持つGCPアカウント

## デプロイ手順

### 初回セットアップ

1. Terraform初期化
```bash
terraform init
```

2. 設定ファイルの準備（オプション）
```bash
cp terraform.tfvars.example terraform.tfvars
# 必要に応じて編集
```

3. インフラストラクチャの作成
```bash
terraform apply
```

### デプロイ方法

#### 方法1: Cloud Buildを使用（推奨）

```bash
# Cloud Build経由でデプロイ（ボリュームマウント含む）
./deploy-with-cloudbuild.sh
```

このスクリプトは以下を自動的に実行します：
- N8Nの最新イメージをデプロイ
- Cloud Storageボリュームをマウント
- 全ての環境変数を設定

#### 方法2: 手動デプロイ

```bash
# 1. Terraformでリソースを作成/更新
terraform apply

# 2. ボリュームマウントを設定
./post-deploy.sh
```

## アクセス情報の取得

```bash
# サービスURL
terraform output service_url

# 認証情報
terraform output -json n8n_credentials

# 暗号化キー（安全に保管してください）
terraform output -raw encryption_key
```

## 重要な注意事項

- **Terraformの制限**: Cloud Run Gen2のボリュームマウントはTerraformでサポートされていません
- **`terraform apply`の影響**: 実行するとCloud Runサービスのボリュームマウント設定が削除されます
- **新しいリビジョン作成時**: 必ずCloud Build経由でデプロイするか、`post-deploy.sh`を実行してください
- **SQLiteの制限**: 同時実行数は1に制限されています
- **本番環境**: SQLiteとCloud Storageの組み合わせは推奨されません
- 詳細な制限事項は../guide.mdを参照してください

## バックアップ

SQLiteデータベースのバックアップスクリプトが用意されています：

```bash
# バックアップの実行
../scripts/backup-n8n.sh
```

## クリーンアップ

```bash
terraform destroy
```

## ファイル一覧

- `main.tf` - メインのリソース定義
- `variables.tf` - 変数定義
- `outputs.tf` - 出力値定義
- `versions.tf` - プロバイダーとバックエンド設定
- `backend.tf` - Terraform state用のGCSバケット定義
- `cloudbuild.yaml` - Cloud Build設定
- `deploy-with-cloudbuild.sh` - Cloud Buildデプロイスクリプト
- `post-deploy.sh` - ボリュームマウント設定スクリプト