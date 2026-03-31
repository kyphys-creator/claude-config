# LaTeX 規約

LaTeX を含むリポで適用。CLAUDE.md から参照: `~/Claude/claude-config/conventions/latex.md`

## 式の安全規則
- **equation/align 環境内は原則変更しない。** 変更は事前にユーザー確認。物理的内容の追加はコメントとして提案（ハルシネーション混入防止）
- 英語校正・文法修正など確実に正しい本文修正は可

## コンパイラ
- 英語のみ → `lualatex`
- 日本語含む → `ptex2pdf`（内部で platex + dvipdfmx）
- BibTeX フルビルド: `platex → bibtex → platex → platex → dvipdfmx`
- リポの CLAUDE.md に手順があればそちらを優先

## JHEP.bst 記法
JHEP.bst はフィールドから自動リンクを生成するので `\href` 手書き不要（二重リンクの原因）。
- `doi`: DOI 本体のみ（例: `10.1103/PhysRevA.61.012104`）
- `eprint`: arXiv ID のみ（例: `quant-ph/9905023`）。`archivePrefix = "arXiv"` と併用
- `url`: doi や eprint があれば不要
- `note`: 自由テキスト。自動リンク対象外の補足情報に使う

## pre-commit hook（Unicode→LaTeX 自動修正）
`setup.sh` が LaTeX リポに自動インストール。手動確認・インストール:
```bash
# 確認: .git/hooks/pre-commit が fix-bib-unicode を指しているか
ls -la .git/hooks/pre-commit
# インストール:
ln -s ~/Claude/claude-config/scripts/pre-commit-bib .git/hooks/pre-commit
```
ステージされた `.tex`/`.bib` 等の非 LaTeX 文字（Unicode 引用符、ダッシュ等）を自動でLaTeXコマンドに変換する。

## .gitignore
**LaTeX 生成 PDF はリポに含める（ignore しない）。** 共同編集者がコンパイル環境を持っていない場合でも最新の PDF を参照できるようにするため。`*.pdf` を ignore する場合は `!<main>.pdf` で除外対象から外す。

共有リポでは共同編集者のために .gitignore に LaTeX 中間ファイルのパターンを明記する（`~/.gitignore_global` に頼らない）:
```
*.aux *.bbl *.blg *.log *.out *.toc *.fdb_latexmk *.fls *.synctex.gz *.synctex(busy) *.dvi
```
