# Scripts

このディレクトリには、N8Nの運用に必要なスクリプトが含まれています。

## スクリプト一覧

### deploy-with-cloudbuild.sh
Cloud Build経由でN8Nをデプロイします。ボリュームマウントの設定も自動的に行います。

```bash
./deploy-with-cloudbuild.sh
```

**実行内容:**
- Terraformの出力値から設定を取得
- Cloud Buildを使用してN8Nをデプロイ
- Cloud Storageボリュームを自動的にマウント

### backup-n8n.sh
SQLiteデータベースをバックアップします。

```bash
./backup-n8n.sh
```

**実行内容:**
- 現在のデータベースをバックアップバケットにコピー
- バックアップファイルの整合性チェック
- 最近のバックアップ一覧を表示

## 注意事項

- すべてのスクリプトはterraformディレクトリでの実行を前提としています
- Cloud Build権限が必要です（terraform applyで自動設定されます）