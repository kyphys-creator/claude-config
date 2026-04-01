# Substack 入稿規約

## エディタの制約

Substack のエディタはリッチテキスト（WYSIWYG）。**Markdown 記法を直接認識しない。** `## 見出し` や `**太字**` をそのまま貼るとプレーンテキストとして表示される。

## 使えるフォーマット（Substack エディタが持つ機能）

- 見出し（H1〜H6）
- **太字** / *イタリック*
- 箇条書き（番号付き / 番号なし）
- 引用ブロック
- リンク
- 脚注
- 画像（ドラッグ＆ドロップ）
- 水平線
- 埋め込み（YouTube, X, Spotify 等）

## 使えないフォーマット

- **テーブル** — サポートなし。箇条書きや見出し付きリストで代替
- **コードブロック** — GitHub Gist 埋め込みのみ（fenced code block 不可）
- **インラインコード** — 不可

## 原稿の書き方

Markdown で書いてよい（見出し・太字・箇条書き等は全て Substack の機能に対応する）。ただし:

1. **テーブルは使わない** → 箇条書きに変換
2. **内部ファイル参照は除去** → `→ concepts.md §7` のような記法は読者に意味がない
3. **コードブロックは使わない** → 必要なら Gist 埋め込み

## 入稿手順

1. `drafts/` フォルダに Markdown 原稿を作成（例: `drafts/article-substack.md`）
2. [md-to-substack.netlify.app](https://md-to-substack.netlify.app/) をブラウザで開く
3. 原稿の全文を左のテキストエリアに貼る
4. 右のプレビューでフォーマットを確認（見出し・太字・箇条書き・水平線）
5. 「Copy for Substack」ボタンを押す → クリップボードにリッチテキストがコピーされる
6. Substack エディタに貼り付け（Cmd+V）
7. タイトルは Substack エディタ側で別途入力（H1 はサブタイトルとして表示される場合がある）

## オプション設定（md-to-substack ツール）

- **Enable smart quotes**: ON 推奨（`"` → `""`）
- **Add extra spacing between lines**: OFF（ON にすると各行が別段落になる）
- **Auto-update preview**: ON

## 注意事項

- 公開前に Substack のプレビュー機能でも最終確認すること
- 画像は md-to-substack では変換されない → Substack エディタで手動挿入
- Substack の Notes（短文投稿）では太字・イタリック・リンクのみ使用可能（見出し・箇条書し不可）
