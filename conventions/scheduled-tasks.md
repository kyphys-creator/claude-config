# Scheduled Tasks 規約

Claude Code scheduled tasks を使うリポで適用。CLAUDE.md から参照: `~/Claude/claude-config/conventions/scheduled-tasks.md`

## アーキテクチャ: SKILL.md とバックエンドの二重構造

### 構造

```
リポ/skill/{task-id}/SKILL.md     ← git 管理（差分追跡・レビュー用）
        ↑ symlink
~/.claude/scheduled-tasks/{task-id}/SKILL.md  ← ローカル参照
        ✗ 実行時には読まれない

Claude バックエンド（リモート）    ← 実際に実行される prompt
```

### なぜこうなっているか

- **SKILL.md をリポに置く理由**: git で差分追跡・コードレビューができる。複数端末間で `git pull` で内容を共有できる
- **バックエンドが SKILL.md を読まない理由**: scheduled task の実行 prompt は `create_scheduled_task` / `update_scheduled_task` 呼び出し時にバックエンドに保存され、以後ローカルファイルは参照されない（Claude Code の仕様）
- **symlink の役割**: ローカルで `~/.claude/scheduled-tasks/` を見たとき、SKILL.md の内容をリポ側で一元管理するための便宜。実行には影響しない

### 制約

SKILL.md を single source of truth にできない。リポの SKILL.md とバックエンドの prompt が乖離するリスクが常にある。

## ルール

### SKILL.md にステップ0: SESSION.md チェックを含める（必須）

Scheduled task のエージェントは CLAUDE.md / CONVENTIONS.md を確実に読む保証がない。そのため SESSION.md の要対応事項が無視されるリスクがある。対策として、**各 SKILL.md の冒頭にステップ0として SESSION.md チェックを明記する**。これは CONVENTIONS.md §3 の「リポでの作業開始手順」を task prompt 内で確実に発火させるためのもの。

CONVENTIONS.md のルール（人間セッション・手動実行をカバー）と SKILL.md のステップ0（scheduled task 自動実行をカバー）は役割が異なり、両方必要。

### SKILL.md 編集時（必須）

1. リポの SKILL.md を編集する
2. **直後に `update_scheduled_task` で prompt フィールドを同期する**
3. コミット・push する

この順序を守らないと、バックエンドが古い prompt のまま実行される。

### 新規タスク作成時

1. `create_scheduled_task` でバックエンドに登録（prompt を渡す）
2. リポに `skill/{task-id}/SKILL.md` を作成（同じ内容）
3. symlink を張る: `ln -s /path/to/repo/skill/{task-id}/SKILL.md ~/.claude/scheduled-tasks/{task-id}/SKILL.md`

### マルチマシン運用

- バックエンドはマシンごとに独立。マシン A で `update_scheduled_task` しても、マシン B のバックエンドは更新されない
- 新しいマシンで pull 後、そのマシンで使う scheduled task は `update_scheduled_task` で prompt を同期すること
- SESSION.md にマシン固有の要対応事項を書いておくと pull 後に気づける

## パス表記について

本ドキュメントおよび各リポの CLAUDE.md では `~/Claude/` をハードコードしている。これは現運用者（odakin）の全マシンで統一されたパスであり、`<base>` のような抽象化は行わない。共同編集者が `~/github/` 等の別パスを使っていても、本規約はリポオーナーの Claude Code scheduled task 運用にのみ適用されるため問題ない。共同編集者が scheduled task を運用する場合は、その時点でパス抽象化を検討する。

## 経緯

- 2026-03 symlink 方式を導入。SKILL.md 編集が自動反映されると想定していた
- 2026-04-01 `inspire-monthly` で同期漏れが発覚。バックエンドが旧 prompt で実行され、存在しないモジュール `arxiv_digest.profile` を呼んで失敗
- 原因調査の結果、バックエンドは SKILL.md を実行時に読まないことが判明。手動同期ルールを導入
