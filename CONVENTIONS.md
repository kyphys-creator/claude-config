# リポジトリ規約

最終更新: 2026-03-31

> **`<base>`** = `claude-config` を clone した親ディレクトリ（例: `~/Claude/`）。
> **正本は `<base>/claude-config/CONVENTIONS.md`。** `<base>/CONVENTIONS.md` は symlink。
> 編集後は `cd <base>/claude-config && git add CONVENTIONS.md && git commit && git push`。

---

## 1. リポジトリ作成・同期

```bash
cd <base>
gh repo create <username>/<name> --private --description "<English description>" --clone
cd <name> && git branch -M main
git add . && git commit -m "Initial commit: <概要>" && git push -u origin main
```

description は英語。リポ一覧の正本は **MEMORY.md**。新規作成前に既存リポを確認。

---

## 2. 必須ファイル

| ファイル | 役割 |
|---------|------|
| `CLAUDE.md` | 永続的指示書（構造・実行方法・復帰手順）。構造変更時のみ更新 |
| `SESSION.md` | 揮発的な現在状態（作業中タスク・直近の決定）。進行に応じて更新 |
| `.gitignore` | ビルド成果物・OS/エディタファイル・機密情報の除外 |

CLAUDE.md は「どうやるか」、SESSION.md は「今どこにいるか」。

### 記録先の判別

| 情報の性質 | 書き先 |
|---|---|
| ユーザーの好み・フィードバック・外部参照 | メモリ |
| 現在の作業状態・未完了タスク | SESSION.md |
| 永続的な仕様・構造・手順 | CLAUDE.md |
| 設計判断とその理由 | DESIGN.md |
| 全プロジェクト共通の規約 | CONVENTIONS.md |
| grep / git log で導出可能な事実 | 書かない |

**よくある間違い:** 進行状態をメモリに書く → SESSION.md に書くべき（リポに入り全端末で共有される）。

DESIGN.md（任意）: 却下した代替案がある・同じ問いが繰り返し出る場合に作成。CLAUDE.md=仕様、DESIGN.md=思想。

---

## 3. 自動更新プロトコル

**人間に言われなくても自動で行う。**

### SESSION.md

タスク完了時、重要な判断時、ファイル作成/大幅変更時、エラー発生時、デプロイ時に更新。

**棚卸し（目安80行以内）:** push 前に確認。完了 `[x]` を除去、実装詳細は git log に委任、他ドキュメントとの重複を排除、恒久的決定は CLAUDE.md に移動。完了経緯・API 出力・他ドキュメントの複写は最初から書かない。

### MEMORY.md（目安150行以内）

メモリ追加時に確認。2週間以上未使用プロジェクトを除去、CONVENTIONS 昇格済みフィードバックを除去、解決済み案件を除去。description を最新に保つ。

### push 前チェック

1. SESSION.md 更新（長ければ棚卸し） 2. CLAUDE.md 更新（構造変更時のみ） 3. 4軸レビュー → commit → push。軽微な変更では 2-3 スキップ可。

### 4軸レビュー

| 軸 | 内容 |
|---|---|
| **整合性** | 変更ファイル間で数値・用語・参照先が一致しているか |
| **無矛盾性** | 既存ルール・テンプレートと矛盾していないか |
| **効率性** | 重複がないか。SESSION.md ~80行、MEMORY.md ~150行以内か |
| **安全性** | 個人情報・認証情報が公開リポに含まれていないか |

### autocompact 復帰

CLAUDE.md → "How to Resume" → SESSION.md → 作業継続

---

## 4. CLAUDE.md テンプレート

```markdown
# <プロジェクト名>

## 概要
<1-2文>

## リポジトリ情報
- パス / ブランチ / リモート

## 構造
<tree>

## 実行環境
- 言語 / 依存 / 実行コマンド

## How to Resume
1. SESSION.md を読む → 現在状態と残タスクを把握
2. 残タスクに従って作業継続

## 自動更新ルール（必須）
CONVENTIONS.md §3 参照。共有リポでは §3 の内容を直接記述。
```

---

## 5. SESSION.md テンプレート

```markdown
# <プロジェクト名> Session

## 現在の状態
**作業中**: <今やっていること>

## 残タスク
- [ ] <未完了タスク> ← ここから再開

## 決定事項（正本未反映分のみ）
```

目安80行以内。`[x]` は蓄積せず除去。作業履歴は git log に委任。

---

## 6. .gitignore

グローバル（`~/.gitignore_global`）で TeX 中間ファイル・.DS_Store 除外済み。共有リポでは全パターンを含める。

**LaTeX 生成 PDF はリポに含める。** `*.pdf` を ignore する場合は `!<main>.pdf` で除外対象から外す。

---

## 7. ディレクトリ命名

`src/` `docs/` `referee/` `analyses/` `tools/` `scripts/`

---

## 8. Git 規約

- ブランチ `main` 統一。コミットメッセージは英語・動詞始まり
- コミット後は常に push。複数リモートがあれば全リモートに push
- セッション終了時は未コミット変更があれば commit + push
- ファイル名にバージョン番号をつけない

---

## 9. 安全規則（絶対厳守）

1. 他人のファイル削除前に `ls` で確認しユーザーに提示
2. 既存データ削除時はリネーム (`mv old old.bak`) を優先提案
3. force push 禁止（必要なら `--force-with-lease`）
4. 機密情報はコミットしない。同じファイルを複数リポに置かない
5. 破壊的操作は事前にユーザー確認。自分のリポのみ操作
6. **LaTeX の式は原則変更しない。** 変更は事前確認。物理的内容の追加はコメントとして提案
7. **LaTeX コンパイラ:** 英語 → `lualatex`、日本語 → `ptex2pdf`。リポの CLAUDE.md に手順があればそちらを優先
8. **JHEP.bst:** `doi` は DOI 本体のみ、`eprint` は arXiv ID のみ。`\href` 手書き不要。`url` は doi/eprint があれば不要
9. **Scheduled task の SKILL.md** はリポを正本、`~/.claude/scheduled-tasks/` からは symlink

---

## 10. 網羅性の検証

「全部」を主張する場合、列挙の前に機械的な検証基準を定め、列挙後に照合する。

---

## 11. ユーザー視点での設計判断

UI・コンテンツ変更は「誰が・どんな状況で・何を求めて見るか」から判断。「整理・統合・削減」は手段であり目的ではない。最初の直感で即答せず、反論されたら深く考える。

---

## 12. その他

- **画像出力**: ファイル名は内容を反映。生成後は `open` で表示
- **GFM ルール**: `<base>/claude-config/gfm-rules.md` 参照
- **MCP ツール**: 操作前にプロファイル取得で接続先アカウントを確認
- **Google Calendar MCP**: 操作前にカレンダー一覧で対象確認。共有カレンダー命名は `{共同研究者名}{自分の名字}共同研究`。イベント作成時は日時・タイトル・参加者をユーザーに確認
