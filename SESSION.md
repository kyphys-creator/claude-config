# SESSION — claude-config

## 現在の状態
**完了**: git-crypt ドキュメント整備・setup.sh unlock ステップ追加、全ファイル push 済み

## 残タスク
なし

## 直近の作業（2026-04-02）

- Hammerspoon 設定追加（`hammerspoon/init.lua`）: Claude for Mac の Cmd+Q 誤終了防止（eventtap で Cmd+Tab 経由も捕捉）
- setup.sh に Step 7（Hammerspoon symlink、macOS 専用ガード付き）を追加
- memory-guard.sh を `exit 2`（自動ブロック）→ `exit 0` + `permissionDecision: "ask"`（ユーザー確認プロンプト）に変更
- git-crypt ドキュメント整備:
  - CONVENTIONS.md §5 に git-crypt 運用ルール（鍵管理・共有方法・バックアップ）追加
  - asset-management, gmail-mcp-config, kakutei-shinkoku-2025 の CLAUDE.md に鍵共有先・バックアップ復元手順を追加（email-office と同等に）
  - setup.sh に Step 5b（git-crypt unlock 自動化）を追加
- 整合性チェックで README.md/README.ja.md の不整合を修正
