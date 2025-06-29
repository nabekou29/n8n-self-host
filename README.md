# n8n Self-Host on Google Cloud Run

## 目的

n8nワークフロー自動化ツールを低コストでセルフホストする。

## アーキテクチャ

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Cloud Run  │────▶│    SQLite    │────▶│  Cloud Storage  │
│    (n8n)    │     │  (GCS FUSE)  │     │   (Persistent)  │
└─────────────┘     └──────────────┘     └─────────────────┘
```

- **Cloud Run**: n8nアプリケーションのホスティング（デフォルトURL or カスタムドメイン\*）
- **SQLite**: GCS FUSEボリューム上のデータベース
- **Cloud Storage**: データの永続化

\*カスタムドメインはCloud Runドメインマッピング（プレビュー機能）を使用

## 構成

```
.
├── terraform/
│   ├── main.tf          # Cloud Run、GCSバケットの定義
│   ├── variables.tf     # プロジェクトIDなどの変数
│   ├── outputs.tf       # サービスURL、暗号化キーの出力
│   └── backend.tf       # Terraformステートの管理
└── README.md
```

## デプロイ

```bash
cd terraform
terraform init
terraform apply
```

## アクセス情報

```bash
terraform output service_url          # n8nのURL
terraform output -raw encryption_key  # 暗号化キー（要保管）
```
