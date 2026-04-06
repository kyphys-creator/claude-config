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

### CONVENTIONS.md §2 表の user-specific instance を除去
- 特定ドメインの参照データを特定 private リポの管理ツールに送る instance 行を削除 (universal table への混入 + 安全規則違反)
- 同等ルールは odakin-prefs に専用ファイルとして移管 + odakin-prefs/CLAUDE.md テーブルに追記
- 詳細と移管先選定の理由は DESIGN.md「CONVENTIONS.md §2 記録判別表」セクション参照

## 今セッションの変更（2026-04-06 第3回）

### `~/Claude/CLAUDE.md` の symlink 化 完了 (戦略 (b))
- 旧 `~/Claude/CLAUDE.md` の内容を odakin-prefs 側に分割移管 (`user-profile.md`, `project-structure.md`)
- odakin-prefs/CLAUDE.md の「読み込み必須」テーブルに 2 ファイル追記
- `~/Claude/CLAUDE.md` → `odakin-prefs/CLAUDE.md` symlink 化
- DESIGN.md「~/Claude/CLAUDE.md の symlink 化」セクションを「完了」に書き換え (移管マッピング・bundling 根拠を記録)
- 残痕: `~/Claude/CLAUDE.md.pre-symlink-backup` (動作確認後に削除予定)

### 残タスクの確定 (2 件 close)
- **git history scrubbing**: 「暫定方針」を外し「**確定: 見送り**」に書き換え (DESIGN.md)。理由は外部キャッシュ残留で完全秘匿不可のため scrubbing 利得が小さく、force-push のコストが上回る
- **CONVENTIONS.md / conventions/ の自己言及 odakin 記述**: 既に「現状維持」確定文言だったため見出しに「(確定: 現状維持 2026-04-06)」を追記してユーザー再確認済みであることを明示

## 残タスク
- [ ] **RUNBOOK 系ファイルの実例運用後再検討**: トリガーは「いずれかのリポで CLAUDE.md からランブックを切り出す具体的ニーズが出たとき」。詳細は DESIGN.md「RUNBOOK 系ファイル」セクション参照
- [ ] **`~/Claude/CLAUDE.md.pre-symlink-backup` の削除**: 次セッション起動時に symlink 経由で正常読み込みを確認したのちに削除
