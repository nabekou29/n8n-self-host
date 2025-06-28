# N8N on Cloud Run トラブルシューティング

## "Rate exceeded" エラーが頻発する場合

Cloud Storageマウントを使用したSQLiteは、頻繁なI/O操作で制限に達することがあります。

### 対処法

1. **実行履歴の保存を無効化**（実装済み）
   ```
   EXECUTIONS_DATA_SAVE_ON_ERROR=none
   EXECUTIONS_DATA_SAVE_ON_SUCCESS=none
   EXECUTIONS_DATA_SAVE_ON_PROGRESS=false
   ```

2. **メモリ設定を調整**
   ```bash
   # variables.tfで memory = "2Gi" に変更
   ```

3. **キャッシュ設定の最適化**
   Cloud Storageマウントオプションで以下を調整：
   - `metadata-cache-ttl-secs=300` → より長い値に
   - `stat-cache-max-size-mb=64` → より大きい値に
   - `type-cache-max-size-mb=8` → より大きい値に

4. **SQLiteの代替案を検討**
   - Cloud SQL for PostgreSQL（コスト増）
   - Firestore（N8Nのサポート外）

## その他の問題

### デプロイ後にアクセスできない
- ヘルスチェックのタイムアウトを確認
- Cloud Runのログを確認：`gcloud run logs read n8n --region=us-central1`

### ワークフローが保存されない
- Cloud Storageのバケット権限を確認
- サービスアカウントの権限を確認

### パフォーマンスが遅い
- Cloud Storageの地域がCloud Runと同じか確認
- SQLiteの制限により、複雑なワークフローは遅くなる可能性があります