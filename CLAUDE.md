# claude-config

## 概要
`~/Claude` 共通設定ファイルを管理する設定リポ。どの端末でも clone + setup.sh で同じ規約が適用される。
Zenn.dev 記事も同梱（zenn-cli + GitHub 連携で自動デプロイ）。

## リポジトリ情報
- パス: `~/Claude/claude-config/`
- ブランチ: `main`
- リモート: `odakin/claude-config` (public, GitHub)

## 構造
```
claude-config/
├── CLAUDE.md        # このファイル（リポ固有の指示書）
├── CONVENTIONS.md   # 全リポ共通規約（正本）
├── README.md        # プロジェクト説明（英語/日本語）
├── setup.sh         # symlink セットアップスクリプト
├── gfm-rules.md     # GFM CJK bold 対策リファレンス
├── package.json     # zenn-cli 依存（Zenn 記事デプロイ用）
├── articles/        # Zenn 記事（zenn-cli + GitHub 連携で自動デプロイ）
├── books/           # Zenn 本（未使用）
├── LICENSE          # MIT
└── .gitignore
```

## セットアップ（新しい端末で）
```bash
mkdir -p ~/Claude && cd ~/Claude
gh repo clone odakin/claude-config
cd claude-config && ./setup.sh
```

setup.sh が自動で行うこと:
1. `~/Claude/CONVENTIONS.md` → `claude-config/CONVENTIONS.md` の相対 symlink 作成
2. `odakin` の全リポを `~/Claude/` 以下に clone（未取得のもののみ）

## Zenn 記事

zenn-cli + GitHub 連携で `articles/` 内のファイルを push すると zenn.dev に自動デプロイ。

| スラッグ | 記事 |
|---------|------|
| `claude-code-multi-project` | 日本語版: Claude Codeが全部忘れる問題を解決する |
| `claude-code-multi-project-en` | English: Solving Claude Code's Memory Loss |

記事のプレビュー: `npx zenn preview` → http://localhost:8000

### 初回セットアップ（手動）
zenn.dev ダッシュボード → デプロイ管理 → GitHub 連携で `odakin/claude-config` を接続。

## How to Resume
1. このリポには SESSION.md は不要（永続的な設定リポのため）
2. 作業内容は CONVENTIONS.md、README.md、articles/ の変更
3. 変更後は commit + push（全リモートに）

## 運用ルール
- CONVENTIONS.md の正本はこのリポ内のファイル
- `~/Claude/CONVENTIONS.md` は symlink（setup.sh が作成）
- CONVENTIONS.md を変更したらこのリポで commit + push
- 他端末では `git pull` で同期

## 自動更新ルール（必須）
以下を人間に言われなくても自動で行う:
- CONVENTIONS.md を変更したら → このリポで commit + push
- CLAUDE.md のルールの詳細は `~/Claude/CONVENTIONS.md` 参照
