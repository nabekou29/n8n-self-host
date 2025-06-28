# N8N Self-Host on Google Cloud Run

Cloud RunでN8Nをセルフホストするためのインフラストラクチャコード

## ⚠️ 重要な警告

このセットアップは**SQLiteとCloud Storage**を使用しており、以下の制限があります：
- ファイルロッキングが機能しない
- パフォーマンスが大幅に低下する（60-100倍遅い）
- データ破損のリスクがある
- **本番環境での使用は推奨されません**

詳細は[guide.md](./guide.md)を参照してください。

## 必要な環境

- Google Cloud アカウント
- Terraform >= 1.0
- gcloud CLI
- 適切な権限

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
gcloud config set project nabekou29
```

### 3. Terraformでのデプロイ

```bash
cd terraform

# 初期化
terraform init

# プランの確認
terraform plan

# デプロイ実行
terraform apply

# Cloud Storageボリュームマウントの設定
./post-deploy.sh
```

### 4. アクセス情報の取得

```bash
# サービスURL
terraform output service_url

# 認証情報（JSONフォーマット）
terraform output -json n8n_credentials

# 暗号化キー（必ず安全に保管）
terraform output -raw encryption_key
```

## バックアップ

定期的なバックアップを実行：

```bash
./scripts/backup-n8n.sh
```

## トラブルシューティング

### データベースロックエラー

同時実行が原因です。Cloud Runの同時実行数が1に設定されていることを確認してください。

### パフォーマンスが遅い

これはCloud Storage + SQLiteの組み合わせによる既知の問題です。改善方法：
- Cloud SQLへの移行を検討
- Compute Engine + SQLiteの使用を検討

## クリーンアップ

```bash
cd terraform
terraform destroy
```

## ライセンス

MIT