# SESSION — claude-config

## 現在の状態
**完了**: dropbox-refs convention (per-repo symlink to a Dropbox shared PDF folder, resolved per-machine via personal-layer YAML registry)

## 今セッションの変更（2026-04-07）

### dropbox-refs convention 新規追加
共同研究のリポから「Dropbox 上の共同 PDF 置き場」を symlink で参照するためのパターンを規約化。Dropbox install 場所が OS / user で違う問題と、subpath が user-specific なため共有リポにハードコードできない問題を、(a) Dropbox root resolver + (b) personal-layer の YAML registry の組み合わせで吸収する。

新規ファイル:
- `scripts/dropbox-root.sh` — `$DROPBOX_ROOT` env → `~/.dropbox/info.json` → 既知の install 場所 fallback chain で Dropbox root を 1 行で返す
- `scripts/setup-dropbox-refs.sh` — personal layer の `dropbox-collabs.yaml` を読み、各 entry について `<base>/<repo>/dropbox-refs` symlink を idempotent に生成。CREATED / UPDATED / WARN を出力、no-change は silent
- `conventions/dropbox-refs.md` — 規約 (What / Why / How / Resolution / When (not) to use / Collaborator usage / 制約 / PyYAML 依存)

`setup.sh` 拡張:
- Step 5a2: 個人層検出後に `dropbox-collabs.yaml` があれば setup-dropbox-refs.sh を呼ぶ + 個人層 `.git/hooks/post-merge` に同スクリプトを install。tagged hook は再 run で常に refresh されるので、layer 移動や script 場所変更後も path が古くならない

ドキュメント更新:
- `CLAUDE.md` 構造表に conventions/, scripts/ の新ファイル追加 + Step 5a2 を 7. の sub-bullet として追記
- `README.md` / `README.ja.md` の conventions/ list と structure tree に追加
- `DESIGN.md` に設計判断記録 (per-repo vs global symlink の選択、YAML over TSV、post-merge 自動化の理由)
- `docs/personal-layer.md` に dropbox-collabs.yaml を mention

### 4 軸チェック後の修正
初実装後に深い 4 軸チェックを実行し、以下を修正:
- **P1 (安全性)**: `dropbox-refs.md` と `setup-dropbox-refs.sh` の YAML 例に collaborator 実名と private リポ名が混入していたのを generic placeholder に置換 (claude-config CLAUDE.md の public-safety 規則違反を解消)
- **P2 (無矛盾性)**: setup.sh の post-merge install ロジックが「tagged hook は触らない」になっていたのを「tagged hook は常に上書き」に修正。layer 移動や DROPBOX_REFS_SCRIPT 場所変更で hook 内の絶対 path が古くなる問題を防止
- **P5 (効率性)**: dropbox-refs.md §3.2 に PyYAML 依存 (`pip3 install pyyaml`) を明記

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

## 今セッションの変更（2026-04-07 第5回: 4 軸レビュー修正）

### DESIGN.md / EXPLORING.md 分離 convention の追加修正
- 前回導入した convention の 4 軸レビューで 6 件のバグを検出し、うち 5 件を修正（[6] 効率性: claude-config/DESIGN.md と principles §6 の内容重複 → DESIGN.md を thin pointer 化）
- **LorentzArena 2+1 側**: 別コミットで用語再考を DESIGN.md → EXPLORING.md に migrate（`88ed267` でヘッダーが誤置換され orphan 化していた問題も併せて解決、stale L428 参照も削除）
- **docs/convention-design-principles.md §6 適用事例**: 「用語再考は当面 DESIGN.md に残す」を削除し、「初回適用リポ内の既存 (b) は EXPLORING.md 新設時に同時 migrate するのが自然」という学びを追記
- **DESIGN.md「DESIGN.md と EXPLORING.md の分離」**: principles §6 と重複していた 3 カテゴリ表・3 つの実害・棄却した代替案を削除し、principles §6 を正本として参照する thin 構成に変更。決定固有の context（トリガー・初回適用・4-07 修正経緯）のみ残す

## 今セッションの変更（2026-04-06 第4回）

### DESIGN.md と EXPLORING.md の分離（新規 convention）
- LorentzArena 2+1/DESIGN.md 500+ 行の肥大化とスマホ UI 思考メモの記録先問題を契機に、DESIGN.md に決定 / 探索 / メタ決定の 3 カテゴリが混在している構造を識別
- **CONVENTIONS.md §2**: DESIGN.md 定義を「決定した設計判断（defer 含む）」に絞り、任意ファイル `EXPLORING.md` を新設（ARCHITECTURE.md と同じ任意ファイル扱い）
- **§2 の 記録先判別表** も更新（DESIGN.md / EXPLORING.md の使い分けを追加）
- **docs/convention-design-principles.md §6 新設**: 3 カテゴリ分析、棄却した代替案（3 ファイル分割・タグ付け・サブディレクトリ）、lifecycle、境界判別ルールを記録
- **DESIGN.md**: 「DESIGN.md と EXPLORING.md の分離（2026-04-06）」セクション追加
- **初回適用**: LorentzArena 2+1/EXPLORING.md を新規作成し、スマホ UI の設計思考（option space 分析、α/β 候補、open questions、un-shelve トリガー）を移動。2+1/SESSION.md の「次にやること」からポインタ
- **retroactive migration はしない**: 既存リポの既存 DESIGN.md は触らない。新規探索が発生したリポから順に導入

## 残タスク
- [ ] **RUNBOOK 系ファイルの実例運用後再検討**: トリガーは「いずれかのリポで CLAUDE.md からランブックを切り出す具体的ニーズが出たとき」。詳細は DESIGN.md「RUNBOOK 系ファイル」セクション参照
- [ ] **規約 rollout 原則の一般化の再検討**: 現状は `docs/convention-design-principles.md §6` に EXPLORING.md 特化の学びとして記録（L149 の 2026-04-07 note、および L148 の scope 明確化）。case 2 発生（RUNBOOK 導入 or 他 content-reorganization 系 convention 追加）で一般原則（principles §7 新設など）に昇格するか再判断。1 データポイントでの formalize は YAGNI で defer 中
