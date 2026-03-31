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
├── CLAUDE.md        # このファイル（リポ固有の指示書）
├── CONVENTIONS.md   # 全リポ共通規約（正本）
├── README.md        # プロジェクト説明（英語/日本語）
├── setup.sh         # symlink + hooks + clone セットアップスクリプト
├── hooks/
│   ├── memory-guard.sh       # メモリ書き込みガード — Edit/Write 用（§2 判別強制）
│   └── memory-guard-bash.sh  # メモリ書き込みガード — Bash 用（警告のみ）
├── scripts/
│   ├── fix-bib-unicode.py    # LaTeX ソースの非LaTeX文字→LaTeX変換スクリプト
│   └── pre-commit-bib        # Git pre-commit hook（上記を呼ぶシェルスクリプト）
├── gfm-rules.md     # GFM CJK bold 対策リファレンス
├── LICENSE          # MIT
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
2. Claude Code hooks を `~/.claude/hooks/` に symlink + `settings.json` に設定マージ
3. git post-merge hook をインストール（`git pull` 後に hooks と CONVENTIONS.md を自動同期）
4. 認証ユーザーの全リポを `<base>/` 以下に clone（未取得のもののみ）
5. LaTeX リポ（.tex/.bib を含む）に pre-commit hook をインストール（Unicode→LaTeX 自動修正）

## How to Resume
1. このリポには SESSION.md は不要（永続的な設定リポのため）
2. 作業内容は CONVENTIONS.md と README.md の変更
3. 変更後は commit + push（全リモートに）

## 安全規則（公開リポ）
**このリポは public。** 以下を絶対にコミットしない:
- 実名（GitHub ユーザー名 `odakin` は可）
- メールアドレス
- 非公開リポ名（→ MEMORY.md に記載）
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
