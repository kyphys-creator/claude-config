# claude-config

## 概要
共通設定ファイルを管理する設定リポ。どの端末でも clone + setup.sh で同じ規約が適用される。

## リポジトリ情報
- パス: `<base>/claude-config/`
- ブランチ: `main`
- リモート: `odakin/claude-config` (public, GitHub)

## 構造
```
claude-config/
├── CLAUDE.md               # このファイル（リポ固有の指示書）
├── SESSION.md              # 現在の作業状態・残タスク
├── CONVENTIONS.md          # 全リポ共通規約（正本）
├── README.md               # プロジェクト説明（English）
├── README.ja.md            # プロジェクト説明（日本語）
├── setup.sh                # セットアップスクリプト
├── conventions/
│   ├── shared-repo.md      # 共有リポ固有規約
│   ├── latex.md            # LaTeX 固有規約（物理リポで参照）
│   ├── mcp.md              # MCP 固有規約（MCP 使用時に参照）
│   ├── scheduled-tasks.md  # Scheduled Tasks 規約（SKILL.md 二重構造・同期ルール）
│   └── substack.md         # Substack 入稿規約（Markdown→リッチテキスト変換手順）
├── hooks/
│   ├── memory-guard.sh         # メモリ書き込みガード — Edit/Write 用（§2 判別強制）
│   └── memory-guard-bash.sh    # メモリ書き込みガード — Bash 用（警告のみ）
├── hammerspoon/
│   └── init.lua                # Hammerspoon 設定（Claude Cmd+Q 誤終了防止）
├── scripts/
│   ├── fix-bib-unicode.py      # Unicode→LaTeX 変換スクリプト
│   └── pre-commit-bib          # Git pre-commit hook（上記を呼ぶ）
├── docs/
│   ├── usage-tips.md           # 運用Tips（English）
│   ├── usage-tips.ja.md        # 運用Tips（日本語）
│   ├── git-crypt-guide.md      # git-crypt 暗号化ガイド（English）
│   └── git-crypt-guide.ja.md   # git-crypt 暗号化ガイド（日本語）
├── gitignore_global        # グローバル gitignore（~/.gitignore_global に symlink）
├── gfm-rules.md            # GFM CJK bold 対策リファレンス
├── LICENSE                  # MIT
└── .gitignore
```

## セットアップ（新しい端末で）
```bash
mkdir -p <base> && cd <base>
gh repo clone odakin/claude-config
cd claude-config && ./setup.sh
```

setup.sh が自動で行うこと:
1. `<base>/CONVENTIONS.md` → `claude-config/CONVENTIONS.md` の symlink（Windows は cp）
2. `~/.gitignore_global` → `claude-config/gitignore_global` の symlink + `git config --global core.excludesfile` 設定
3. Claude Code hooks を `~/.claude/hooks/` に symlink + `settings.json` に設定マージ
4. Claude Code パーミッション設定 — 安全なツール（Bash, Read, Edit, Write, Glob, Grep, WebFetch, WebSearch）を自動許可
5. git post-merge hook をインストール（`git pull` 後に hooks と CONVENTIONS.md を自動同期）
6. 認証ユーザーの全リポを `<base>/` 以下に clone（未取得のもののみ）
7. LaTeX リポ（.tex/.bib を含む）に pre-commit hook をインストール（Unicode→LaTeX 自動修正）
8. *(条件付き)* git-crypt 暗号化リポを自動 unlock（`~/.secrets/git-crypt.key` が存在する場合のみ）
9. *(条件付き)* Hammerspoon 設定をインストール（macOS + Hammerspoon インストール済みの場合のみ）

## How to Resume
1. SESSION.md を読む → 現在状態と残タスクを把握
2. 残タスクに従って作業継続
3. 変更後は commit + push（全リモートに）

## 安全規則（公開リポ）
**このリポは public。** 以下を絶対にコミットしない:
- 実名（GitHub ユーザー名 `odakin` は可）
- メールアドレス
- 非公開リポ名（→ MEMORY.md に記載）。ただし汎用ツール設定リポ名（`gmail-mcp-config` 等）は可
- 金融データ・口座情報
- 所属機関名
- 他ユーザーのユーザー名

変更前に「公開リポに載せて問題ないか」を必ず確認すること。

## 運用ルール
- CONVENTIONS.md の正本はこのリポ内のファイル
- `<base>/CONVENTIONS.md` は symlink（setup.sh が作成。Windows は cp + post-merge hook で自動同期）
- CONVENTIONS.md を変更したらこのリポで commit + push
- 他端末では `git pull` で同期

## 自動更新ルール（必須）
以下を人間に言われなくても自動で行う:
- CONVENTIONS.md を変更したら → このリポで commit + push
- CLAUDE.md のルールの詳細は `<base>/CONVENTIONS.md` 参照
