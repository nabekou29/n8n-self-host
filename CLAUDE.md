# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

n8nワークフロー自動化ツールをGoogle Cloud Runでセルフホストするためのインフラストラクチャコード。Terraformを使用してGCPリソースを管理。

## アーキテクチャ

- **Cloud Run**: n8nアプリケーションのホスティング
- **SQLite on GCS FUSE**: Cloud StorageをFUSEマウントしたボリューム上のデータベース
- **Cloud Storage**: データとバックアップの永続化

## 重要なコマンド

### デプロイメント
```bash
cd terraform
terraform init    # 初回またはプロバイダー更新時
terraform plan    # 変更内容の確認
terraform apply   # リソースのデプロイ
```

### デプロイ後の情報取得
```bash
terraform output service_url          # n8nのアクセスURL
terraform output -raw encryption_key  # 暗号化キー（要保管）
terraform output n8n_url             # カスタムドメインまたはデフォルトURL
terraform output dns_records         # カスタムドメイン設定時のDNSレコード
```

### リソース管理
```bash
terraform state list    # 管理されているリソース一覧
terraform destroy      # リソースの削除（注意：データも削除される）
```

## プロジェクト構造

- **terraform/**: インフラストラクチャ定義
  - `main.tf`: Cloud Run、Storage、IAM等のリソース定義
  - `variables.tf`: 設定可能な変数（project_id、region、custom_domain等）
  - `outputs.tf`: デプロイ後に取得可能な情報
  - `backend.tf`: Terraformステート管理（GCSバケット）
  - `versions.tf`: プロバイダーバージョン指定

## 設定のカスタマイズ

### 必須設定
- `project_id`: GCPプロジェクトID（デフォルト: "nabekou29"）
- `region`: デプロイリージョン（デフォルト: "us-central1"）

### オプション設定
- `custom_domain`: カスタムドメイン（例: "n8n.example.com"）
- `n8n_encryption_key`: 既存の暗号化キー（未指定時は自動生成）
- `service_name`: Cloud Runサービス名（デフォルト: "n8n"）

## セキュリティ考慮事項

1. **暗号化キー**: `terraform output -raw encryption_key`で取得した値は安全に保管すること
2. **パブリックアクセス**: デフォルトでallUsersからのアクセスが許可されている（n8n内蔵認証を使用）
3. **サービスアカウント**: 最小権限の原則に基づいて設定済み

## トラブルシューティング

### Terraformステートの競合
```bash
terraform refresh  # ステートと実際のリソースを同期
```

### n8nへのアクセス問題
1. Cloud Runのログを確認: GCPコンソール → Cloud Run → ログ
2. ヘルスチェックエンドポイント: `/healthz`
3. 起動に時間がかかる場合があるため、数分待つ

### カスタムドメイン設定
1. `terraform output dns_records`でCNAMEレコード情報を取得
2. DNSプロバイダーでCNAMEレコードを設定（ghs.googlehosted.com）
3. SSL証明書の発行には最大24時間かかる場合がある