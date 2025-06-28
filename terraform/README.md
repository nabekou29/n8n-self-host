# N8N on Cloud Run - Terraform Configuration

このディレクトリには、Cloud RunでN8NをデプロイするためのTerraform設定が含まれています。

## 前提条件

- Terraform >= 1.0
- Google Cloud SDK (gcloud)
- 適切な権限を持つGCPアカウント

## デプロイ手順

1. Terraform初期化
```bash
terraform init
```

2. 設定ファイルの準備（オプション）
```bash
cp terraform.tfvars.example terraform.tfvars
# 必要に応じて編集
```

3. デプロイプランの確認
```bash
terraform plan
```

4. デプロイ実行
```bash
terraform apply
```

5. Cloud Storageボリュームマウントの設定
```bash
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

## 注意事項

- Cloud Storageボリュームマウントは現在Terraformで直接設定できないため、post-deploy.shスクリプトで設定します
- SQLiteとCloud Storageの組み合わせは本番環境には推奨されません
- 詳細な制限事項は../guide.mdを参照してください

## クリーンアップ

```bash
terraform destroy
```