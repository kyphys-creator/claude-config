# SESSION — claude-config

## 現在の状態
**完了**: git-crypt ドキュメント整理完了、全ファイル push 済み

## 残タスク
なし

## 直近の作業（2026-04-02）

- Hammerspoon 設定追加（`hammerspoon/init.lua`）: Claude for Mac の Cmd+Q 誤終了防止（eventtap で Cmd+Tab 経由も捕捉）
- memory-guard.sh を `exit 2`（自動ブロック）→ `exit 0` + `permissionDecision: "ask"`（ユーザー確認プロンプト）に変更
- git-crypt ドキュメント整理:
  - 鍵管理の正本を gmail-mcp-config/CLAUDE.md に一本化
  - 他3リポ（asset-management, email-office, kakutei-shinkoku-2025）は unlock コマンド + gmail-mcp-config 参照に簡素化
  - CONVENTIONS.md（public）から鍵パス・バックアップ詳細を除去
  - setup.sh: リポ名ハードコードを `.gitattributes` 自動検出に変更
