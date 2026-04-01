# claude-config

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) で複数プロジェクトを一元管理するための共有規約・セットアップツール。

> **English version**: [README.md](README.md)

## なぜこのリポが必要か

Claude Code のコンテキストウィンドウは有限で、長い会話は圧縮（autocompact）される。構造化された復帰パスがなければ、作業中の状態は失われる。プロジェクトが増えるほどこの問題は倍増し、手作業で規律を維持するのは現実的でない。

このリポが提供するもの:

- **CONVENTIONS.md** — 「何をどこに書くか」のルール一式。autocompact 復帰が常に機能する
- **conventions/** — ドメイン固有規約（LaTeX、MCP、共有リポ）。必要な場面でのみロード
- **setup.sh** — ワンコマンドでセットアップ完了: symlink・hooks・パーミッション・全リポ clone
- **hooks/** — 規約を機械的に強制する Claude Code hooks
- **scripts/** — Git pre-commit hooks（LaTeX Unicode 自動修正）

規約の正本を1つだけ持ち、ワークスペースに symlink する。全プロジェクトが重複なく同じプロトコルに従う。

## クイックスタート

```bash
mkdir -p ~/Claude && cd ~/Claude
gh repo clone <your-username>/claude-config
cd claude-config && ./setup.sh
```

`setup.sh` が行うこと:

1. `CONVENTIONS.md` を親ディレクトリに symlink
2. グローバル gitignore をインストール（`~/.gitignore_global` → `claude-config/gitignore_global`）
3. Claude Code hooks（memory-guard）を `~/.claude/hooks/` にインストール + `settings.json` に設定マージ
4. Claude Code パーミッション設定 — 安全なツール（Bash, Read, Edit, Write, Glob, Grep, WebFetch, WebSearch）を自動許可
5. git `post-merge` hook をインストール（`git pull` 後に自動同期）
6. GitHub 上の全リポを clone（既存はスキップ）
7. LaTeX リポに pre-commit hook をインストール（`.tex`/`.bib` の Unicode→LaTeX 自動修正）

> **`<base>`** = `claude-config` を clone した親ディレクトリ（例: `~/Claude/`）。`setup.sh` が自動検出。

Windows（MSYS/Cygwin）では symlink の代わりにファイルコピーを使用し、`post-merge` hook が自動同期する。

## リポ構成

```
~/Claude/                       # 推奨ベースディレクトリ
├── CONVENTIONS.md → claude-config/CONVENTIONS.md  (symlink)
├── claude-config/              # このリポ
│   ├── CLAUDE.md               # リポ固有の指示書
│   ├── SESSION.md              # 現在の作業状態・残タスク
│   ├── CONVENTIONS.md          # 共有規約（正本）
│   ├── README.md               # English 版
│   ├── README.ja.md            # このファイル（日本語）
│   ├── setup.sh                # セットアップスクリプト
│   ├── conventions/            # ドメイン固有規約
│   │   ├── shared-repo.md      # 共有リポ: Git workflow、.gitignore、~ パス
│   │   ├── latex.md            # LaTeX: 式の安全規則、コンパイラ、JHEP.bst、pre-commit
│   │   └── mcp.md              # MCP/GCal: 操作前確認、命名規則
│   ├── hooks/                  # Claude Code hooks
│   │   ├── memory-guard.sh         # Edit/Write ガード
│   │   └── memory-guard-bash.sh    # Bash ガード（警告のみ）
│   ├── scripts/                # Git hooks
│   │   ├── fix-bib-unicode.py      # Unicode→LaTeX 変換
│   │   └── pre-commit-bib          # pre-commit hook シェルラッパー
│   ├── docs/
│   │   ├── usage-tips.md           # 運用Tips（English）
│   │   └── usage-tips.ja.md        # 運用Tips（日本語）
│   ├── gitignore_global        # → ~/.gitignore_global (symlink)
│   ├── gfm-rules.md            # CJK markdown リファレンス
│   └── LICENSE                  # MIT
├── project-a/
├── project-b/
└── ...
```

各プロジェクトの `CLAUDE.md` は `CONVENTIONS.md` を共通規約として参照し、`conventions/*.md` のドメイン固有規約を必要に応じて参照する。ドメイン規約は必要な場面でのみロードされ、毎セッションでは読まれない。

## 含まれるもの

### CONVENTIONS.md

全プロジェクト共通の規約。詳細は [CONVENTIONS.md](CONVENTIONS.md) 参照。

### conventions/

ドメイン固有規約。必要な場面でのみロード:

- **[shared-repo.md](conventions/shared-repo.md)** — 共有リポ向けルール: Git workflow ガード、`.gitignore` 要件、`~` パス禁止
- **[latex.md](conventions/latex.md)** — LaTeX 固有ルール: 式の安全規則（AI による無断編集禁止）、コンパイラ設定、`JHEP.bst`、Unicode クリーンアップ pre-commit hook
- **[mcp.md](conventions/mcp.md)** — MCP コネクタルール: 操作前のアカウント確認、Google Calendar 命名規則

### Hooks: memory-guard

CONVENTIONS.md §2 は情報の書き先を明確に定義している:

| 情報の性質 | 書き先 |
|---|---|
| ユーザーの好み・フィードバック・外部参照 | メモリ（`~/.claude/`） |
| 現在の作業状態・タスク | SESSION.md |
| 永続的な仕様・構造 | CLAUDE.md |
| 設計判断とその理由 | DESIGN.md |
| 全プロジェクト共通の規約 | CONVENTIONS.md |
| コード・git から導出可能 | 書かない |

memory-guard hooks はこの判別を機械的に強制する:

- **`memory-guard.sh`**（Edit/Write 対象）— メモリディレクトリへの書き込みをブロック。書き先が本当にメモリで正しいか確認を強制する。MEMORY.md（インデックス）は通過。
- **`memory-guard-bash.sh`**（Bash 対象）— シェルコマンドでメモリへの書き込みを検出したら警告。ブロックはしない（誤検知リスクがあるため）。

どちらも `setup.sh` が symlink でインストールするため、`git pull` で自動更新。

### Scripts

- **`fix-bib-unicode.py`** — `.tex`/`.bib` ファイル中の非 LaTeX Unicode 文字（em ダッシュ、波ダッシュ、丸括弧付き数字等）を LaTeX 等価物に変換
- **`pre-commit-bib`** — 上記スクリプトを自動実行する Git pre-commit hook。`setup.sh` が LaTeX ファイルを含むリポにインストール。

### その他

- **`gitignore_global`** — OS ファイル・TeX 中間ファイル・エディタファイルのグローバル gitignore。`setup.sh` が `~/.gitignore_global` に symlink。
- **`gfm-rules.md`** — GFM で CJK テキストを扱う際のレンダリング問題リファレンス。bold マーカー（`**`）が日本語文字に隣接すると崩れる問題と回避策。

## 核となるコンセプト

### CLAUDE.md と SESSION.md

- **CLAUDE.md** = 「このプロジェクトの作業方法」— 構造、ビルドコマンド、復帰手順。更新は稀。
- **SESSION.md** = 「今どこにいるか」— 現在のタスク、進捗、直近の決定。継続的に更新。

この分離が autocompact 復帰の土台: CLAUDE.md は常に読み込まれ、「How to Resume」セクションが SESSION.md を指し、SESSION.md に作業継続に必要な全情報がある。

### push 前チェック

`git push` の前に、SESSION.md と CLAUDE.md がプロジェクトの実態を反映しているか確認する。4軸レビュー（整合性・無矛盾性・効率性・安全性）を含むプロトコル。この1つの習慣がドキュメントの陳腐化を防ぐ — 実運用では、ほぼ毎回何か見つかる。

### autocompact 復帰

Claude Code のコンテキストが圧縮されたとき:

1. CLAUDE.md が自動読み込みされる（常にコンテキスト内）
2. 「How to Resume」セクションが SESSION.md の参照を指示
3. SESSION.md が現在の状態・残タスク・直近の決定を提供
4. シームレスに作業を継続

SESSION.md の正確さが生命線。古ければ復帰は失敗する。

### 安全規則

[CONVENTIONS.md §5](CONVENTIONS.md) および [conventions/latex.md](conventions/latex.md)（LaTeX 固有ルール）参照。

## 運用Tips

20以上のプロジェクトの実運用で見つけた実践パターン:

- **日本語**: [docs/usage-tips.ja.md](docs/usage-tips.ja.md)
- **English**: [docs/usage-tips.md](docs/usage-tips.md)

## カスタマイズ

フォークして CONVENTIONS.md を自分のワークフローに合わせて編集する。規約は日本語だが構造は言語非依存。`setup.sh` は認証ユーザーを自動検出するのでそのまま動作する。

## ライセンス

MIT
