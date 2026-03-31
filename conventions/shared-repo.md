# 共有リポ規約

共同編集者がいるリポで適用。CLAUDE.md から参照: `~/Claude/claude-config/conventions/shared-repo.md`

## Git workflow（必須）

### セッション開始時
「作業開始」「スタート」等の合図があったら:
1. `git status` で状態チェック
   - **未コミット変更あり** → 「前回の変更が未 commit です。先に commit & push しますか？」
   - **未 push コミットあり** → 「前回の commit が未 push です。先に push しますか？」
2. `git pull` でリモートと同期（コンフリクト発生時はユーザーと解決）
3. リマインダー表示: **「作業が終わったら commit & push を忘れずに！」**

### セッション終了時
「おわり」「終了」「今日はここまで」等の合図、またはお礼・挨拶があったら:
- `git status` を実行し、未コミット/未 push があればリマインドする
- クリーンなら「変更なし。お疲れさまでした。」

## .gitignore

共同編集者が `~/.gitignore_global` を設定しているとは限らない。共有リポでは `.gitignore` に全パターンを明記する:
```
.DS_Store
*~
*.swp
*.swo
```
LaTeX リポの場合は [conventions/latex.md](latex.md) の .gitignore セクションも参照。

## パスの記述
CLAUDE.md・SESSION.md 等でローカルパスを書くときは `~` 表記を使う（`/Users/<user>/` は共同編集者の環境で壊れる）。
