# ~/Claude リポジトリ規約

新規リポ作成時・既存リポ整備時に参照する標準規約。
最終更新: 2026-03-16

---

## 1. リポジトリ作成手順

```bash
# 1. GitHub に private リポ作成 + clone
cd ~/Claude
gh repo create odakin/<name> --private --description "<説明>" --clone

# 2. ブランチ名を main に統一
cd <name>
git branch -M main

# 3. 必須ファイルを作成（後述のテンプレート参照）
# 4. initial commit + push
git add . && git commit -m "Initial commit: <概要>"
git push -u origin main
```

## 1.5. 未 clone リポの同期

~/Claude 以下を最新にする際、GitHub 上の odakin アカウントにあるがローカルに clone されていないリポがあれば取得する。

```bash
# 1. GitHub 上の odakin リポ一覧を取得
gh repo list odakin --limit 50 --json name

# 2. ~/Claude に存在しないリポを clone
cd ~/Claude
gh repo clone odakin/<name>
```

**注意**: clone 後はセクション9のリポ一覧にも追記すること。

---

## 2. 必須ファイル

| ファイル | 役割 | 必須度 |
|---------|------|--------|
| `CLAUDE.md` | **永続的な指示書**。プロジェクト概要、構造、実行方法、再開手順。セッションをまたいで不変。 | ★★★ |
| `SESSION.md` | **揮発的な作業ログ**。現在の作業状態、直近の決定事項、次のステップ。作業の進行に応じて更新。 | ★★★ |
| `.gitignore` | ビルド成果物・OS/エディタファイル・機密情報の除外 | ★★★ |
| `docs/` | 参考資料（PDF、ノート等）を格納するディレクトリ | ★★ |

### CLAUDE.md と SESSION.md の役割分担

- **CLAUDE.md = 憲法 + 自動復帰の入口**：プロジェクトの構造・ルール・実行方法。構造変更時のみ更新。autocompact 後に最初に読まれるファイル。
- **SESSION.md = 生きた作業状態**：今何をしているか、何が終わったか、次に何をするか。**作業の進行に応じて自動的に更新される**。
- 原則: CLAUDE.md は「どうやるか」、SESSION.md は「今どこにいるか」。

---

## 3. 自動更新プロトコル（全リポ共通・必須）

### SESSION.md の自動更新タイミング

**以下のタイミングで SESSION.md を必ず更新する。人間に言われなくても自動で行う。**

| タイミング | 更新内容 |
|-----------|---------|
| タスク完了時 | 完了したタスクを `[x]` にし、成果物・変更ファイルを記録 |
| 重要な判断時 | ユーザーの決定・方針変更を「直近の決定事項」に記録 |
| ファイル作成/大幅変更時 | 変更したファイルのパスと概要を記録 |
| エラー・ブロッカー発生時 | 問題の内容と状態を記録 |
| 長い作業の区切り | 中間状態を記録（autocompact に備える） |
| **外部公開・デプロイ時** | **日時・コミット・内容を SESSION.md のデプロイ履歴テーブルに追記**（zenn push、論文投稿、arXiv 投稿等） |

### CLAUDE.md の更新タイミング

**以下の場合にのみ CLAUDE.md を更新する:**

| タイミング | 更新内容 |
|-----------|---------|
| リポ構造が変わったとき | 構造図 (tree) を更新 |
| 新しい実行手順が確定したとき | 実行環境セクションを更新 |
| Phase が大きく進んだとき | "How to Resume" の手順を更新 |

### autocompact 復帰フロー

autocompact が発生すると、Claude Code は CLAUDE.md を自動的に読み込む。
CLAUDE.md の冒頭に復帰手順を書いておくことで、自動的に作業を再開できる。

```
autocompact 発生
  → CLAUDE.md 自動読み込み
  → "How to Resume" セクションに従い SESSION.md を読む
  → SESSION.md の「現在の状態」「次のステップ」から作業を継続
```

**重要**: この復帰が機能するためには、SESSION.md が常に最新である必要がある。
だから上記の自動更新タイミングを守ることが不可欠。

### プッシュ前整合性チェック（全リポ共通・必須）

**`git push` の前に以下を確認する。人間に言われなくても自動で行う。**

1. **SESSION.md が最新か**: 現在の作業状態・完了タスク・次のステップが実態と一致しているか
2. **CLAUDE.md が最新か**: そのセッションで構造変更・手順変更・Phase 進行があった場合、CLAUDE.md に反映されているか
3. **CONVENTIONS.md との整合性**（CLAUDE.md を更新した場合のみ）: テンプレート構成・必須セクション・命名規約と矛盾しないか
4. **CONVENTIONS.md 自体を変更した場合**: 既存リポの CLAUDE.md に波及する変更がないか確認し、必要なら影響リポの CLAUDE.md も更新

```
push 前チェックフロー:
  1. SESSION.md の「現在の状態」「次のステップ」を実態に合わせて更新
  2. CLAUDE.md の更新が必要か判断 → 必要なら更新
  3. CLAUDE.md を更新した場合 → CONVENTIONS.md と矛盾がないか確認
  4. commit → push
```

**注意**: 軽微な変更（typo修正、コメント追加等）で CLAUDE.md に影響がない場合、ステップ 2-3 はスキップしてよい。

---

## 4. CLAUDE.md テンプレート

```markdown
# <プロジェクト名>

## 概要
<1-2文でプロジェクトの目的を説明>

## リポジトリ情報
- パス: `~/Claude/<name>/`
- ブランチ: `main`
- リモート: `odakin/<name>` (private, GitHub)

## 構造
\`\`\`
<name>/
├── CLAUDE.md
├── SESSION.md
├── src/
├── docs/
└── ...
\`\`\`

## 実行環境
- 言語: <Python 3.x / LaTeX / etc.>
- 依存: <pip install ... / brew install ... / なし>
- 実行: <コマンド例>

## How to Resume（autocompact 復帰手順）
**autocompact 後・新規セッション開始時、必ずこの手順を実行:**
1. `SESSION.md` を読む → 現在の作業状態と次のステップを把握
2. SESSION.md の「次のステップ」に従って作業を継続
3. 不明点があればユーザーに確認

## 自動更新ルール（必須）
以下を人間に言われなくても自動で行う:
- タスク完了時 → SESSION.md を更新（完了マーク + 成果物記録）
- 重要な判断時 → SESSION.md に決定事項を記録
- ファイル作成/大幅変更時 → SESSION.md に記録
- CLAUDE.md のルールの詳細は `~/Claude/CONVENTIONS.md` 参照
```

---

## 5. SESSION.md テンプレート

```markdown
# <プロジェクト名> Session

## 現在の状態
**作業中**: <今やっていること or 待ち状態の説明>

### タスク進捗
- [x] <完了したタスク1>
- [ ] <進行中のタスク2> ← **ここから再開**
- [ ] <未着手のタスク3>

## 次のステップ
1. <最も優先度の高い次のアクション>
2. <その次>

## 直近の決定事項
- <日付>: <決定内容>

## 作業ログ
### <日付>
- <何をしたか>
- 変更ファイル: `path/to/file`
```

**SESSION.md の書き方ルール:**
- 「現在の状態」と「次のステップ」を常に最上部に置く（復帰時に最初に目に入るように）
- 完了タスクは `[x]`、進行中は `[ ]` + 「← ここから再開」マーカー
- 作業ログは下に追記していく（上が最新状態、下が履歴）

---

## 6. .gitignore 標準構成

プロジェクトの言語に応じて以下を組み合わせる:

```gitignore
# === 共通（全プロジェクト） ===
.DS_Store
Thumbs.db
*~
*.swp
*.swo
.claude/

# === Python ===
__pycache__/
*.pyc
*.pyo
.venv/
venv/

# === LaTeX ===
*.aux
*.bbl
*.blg
*.log
*.out
*.toc
*.synctex.gz
*.synctex
*.fls
*.fdb_latexmk

# === Mathematica ===
*.mx

# === Node.js ===
node_modules/
package-lock.json  # 必要なら残す

# === 出力ファイル ===
plot_output.png
*.tmp
```

---

## 7. ディレクトリ命名規約

| パターン | 用途 | 例 |
|---------|------|-----|
| `src/` | メインソースコード・原稿 | LaTeX, Python スクリプト |
| `docs/` | 参考資料・外部文献 | PDF, メモ |
| `referee/` | レフェリーレポート（論文リポ） | レポート PDF |
| `analyses/` | 解析スクリプト・ノートブック | Mathematica, Jupyter |
| `tools/` | ユーティリティスクリプト | パーサー、変換器 |
| `scripts/` | 自動化スクリプト | ビルド、デプロイ |

---

## 8. Git 規約

- **ブランチ**: `main` に統一（`master` は使わない）
- **コミットメッセージ**: 英語、1行目は動詞始まり（`Add`, `Fix`, `Update`）
- **大きなファイル**: PDF 等で push が失敗したら `git config http.postBuffer 157286400`
- **バージョン管理**: ファイル名に番号をつけない（`fixed1`, `fixed2` 等は禁止）。git がバージョン管理する。
- **機密情報**: `.env`, `credentials`, 個人情報を含むファイルはコミットしない
- **コミット後は常に push**: `git commit` したら必ず `git push` まで行う。手動 push 忘れを防ぐ。
- **セッション終了時は必ず commit + push**: 作業が一段落したとき・ユーザーとの会話が終わりそうなとき、未コミットの変更があれば commit & push してから終了する。変更を手元に残したまま終わらない。

---

## 9. リポ一覧

| リポ | パス | 用途 | ブランチ |
|------|------|------|---------|
| multi-agent-shogun | ~/Claude/multi-agent-shogun | マルチエージェント開発基盤 | main |
| einstein-cartan | ~/Claude/einstein-cartan | EC重力理論ゲージ不変性検証 | main |
| epstein-article | ~/Claude/epstein-article | エプスタイン記事（zenn） | main |
| ejp-revision | ~/Claude/ejp-revision | EJP論文改訂 | main |
| bayes-kai | ~/Claude/bayes-kai | ベイズ統計・中性子寿命 | main |
| kakutei-shinkoku-2025 | ~/Claude/kakutei-shinkoku-2025 | 確定申告2025 | main |
| mhlw-ec-pharmacy-finder | ~/Claude/mhlw-ec-pharmacy-finder | 厚労省EC薬局検索 | main |
| physics-research | ~/Claude/physics-research | 物理研究 | main |
| ishida-tsutsumi-map | ~/Claude/ishida-tsutsumi-map | 石田堤マップ | main |
| codex-shogun-system | ~/Claude/codex-shogun-system | Codex Shogun システム | main |
| EMrel | ~/Claude/EMrel | 電磁相対論 | main |
| webGL-test | ~/Claude/webGL-test | WebGLテスト | main |
| claude-config | ~/Claude/claude-config | 共通設定（CONVENTIONS.md等） | main |

**注意**: odakin のリポのみ操作する。yohey-w は絶対に触らない。

---

## 10. 安全規則

1. **削除前に確認**: `rm -rf` の前に必ずパスを確認。プロジェクト外のパスは触らない。ただし、Claude が当該セッションで自ら作成したファイルの削除は承認不要。
2. **force push 禁止**: `git push --force` は使わない。必要なら `--force-with-lease`。
3. **機密ファイル**: `.env`, 認証情報、個人情報はコミットしない。
4. **ファイルの重複禁止**: 同じファイルを複数リポに置かない。1つの正本を決める。
5. **破壊的操作は必ず事前確認**: リポ削除、ブランチ削除、ファイル一括削除、`git reset --hard` など不可逆な操作を行う前に、必ずユーザーに確認を取る。暗黙の了解で実行しない。
