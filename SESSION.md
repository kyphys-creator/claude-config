# SESSION — claude-config

## 現在の状態
**完了**: Hammerspoon 設定追加・memory-guard フック変更・整合性修正、全ファイル push 済み

## 残タスク
なし

## 直近の作業（2026-04-02）

- Hammerspoon 設定追加（`hammerspoon/init.lua`）: Claude for Mac の Cmd+Q 誤終了防止（eventtap で Cmd+Tab 経由も捕捉）
- setup.sh に Step 7（Hammerspoon symlink、macOS 専用ガード付き）を追加
- memory-guard.sh を `exit 2`（自動ブロック）→ `exit 0` + `permissionDecision: "ask"`（ユーザー確認プロンプト）に変更
- 整合性チェックで6件の不整合を検出・修正:
  - README.md / README.ja.md: Step 8 追加、ツリーに `hammerspoon/`・`scheduled-tasks.md`・`substack.md` 追加、memory-guard 説明更新
  - `.gitignore` に `__pycache__/` 追加
