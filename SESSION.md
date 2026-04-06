# SESSION — claude-config

## 現在の状態
**完了**: PATH 二層防御（.zprofile 修正 + REQUIRED_PATHS 方式スナップショットパッチ）

## 今セッションの変更（2026-04-03）

### PATH 管理の二層防御
- **根本原因特定**: `.zprofile` の `brew shellenv` が `.zshenv` の if-blocks で追加した TeX/Python PATH を上書き。macOS login shell の起動順（`.zshenv` → `/etc/zprofile` → `~/.zprofile`）で3回 path_helper が走り、最後の `.zprofile` が PATH を再構築していた
- **第1層**: `.zprofile` から `brew shellenv` を除去。PATH 設定は `~/.zshenv` に一元化
- **第2層**: `fix-snapshot-path-patch.sh` を REQUIRED_PATHS 方式に更新（旧: `grep 'export PATH=/usr/bin'` + FULL_PATH 全置換 → 新: 不足検出・追加。Claude Code v2.1.87 の形式変更に対応）
- `setup.sh` に Step 2c 追加（`.zprofile` の重複 `brew shellenv` を自動修正）
- `conventions/shell-env.md` 全面改訂（問題・PATH 構築順・二層防御の説明）
- `DESIGN.md` に PATH 管理セクション拡充（根本原因 + 第1層/第2層 + REQUIRED_PATHS 方式の設計理由）
- `CLAUDE.md` のステップ一覧を更新（Step 4 に .zprofile 修正を統合）

### 前回セッション（同日）
- DESIGN.md を必須ファイルに昇格（CONVENTIONS.md §2）
- conventions/shell-env.md 新規追加（PATH スナップショット修正、deny ルール）
- hooks/fix-snapshot-path-patch.sh 追加（launchd WatchPaths 用）
- CONVENTIONS.md §5 に OS セキュリティ設定変更禁止を追加
- dangerous-commands-guard.sh を削除（deny ルールで十分）

## 今セッションの変更（2026-04-06）

### ARCHITECTURE.md と RUNBOOK 系の位置づけ決着
- **ARCHITECTURE.md**: 必須化せず CONVENTIONS.md §2 に「任意ファイル」として追加（5 行）。判断の根拠と棄却した代替案は DESIGN.md の該当セクション参照
- **RUNBOOK 系**: 規約化を待つ（実例不足）。判断の根拠は DESIGN.md の該当セクション参照
- 30 リポ実地レビューの結果と「CLAUDE.md 肥大化の真因はランブック」という発見も DESIGN.md に記録済み

## 残タスク
- [ ] **RUNBOOK 系ファイルの実例運用後再検討**: トリガーは「いずれかのリポで CLAUDE.md からランブックを切り出す具体的ニーズが出たとき」。詳細は DESIGN.md「RUNBOOK 系ファイル」セクション参照
