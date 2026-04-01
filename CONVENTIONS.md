# リポジトリ規約

最終更新: 2026-03-31

> **正本は `~/Claude/claude-config/CONVENTIONS.md`。** `~/Claude/CONVENTIONS.md` は symlink。
> 編集後は `cd ~/Claude/claude-config && git add -A && git commit && git push`。
> ドメイン固有規約は `conventions/` に分離: [shared-repo.md](conventions/shared-repo.md), [latex.md](conventions/latex.md), [mcp.md](conventions/mcp.md), [substack.md](conventions/substack.md)
>
> **パスの記述規則:** CLAUDE.md・SESSION.md 等でローカルパスを記述する際は `~` で表記（例: `~/Dropbox/...`）。`/Users/odakin/` のようなユーザー固有の絶対パスは共同編集者の環境で壊れるため使わない。

---

## 1. リポジトリ作成・同期

```bash
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
| `.gitignore` | ビルド成果物・OS/エディタファイル・機密情報の除外。共有リポでは全パターン明記 |

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

---

## 3. 自動更新プロトコル

**人間に言われなくても自動で行う。**

SESSION.md: タスク完了時、重要な判断時、ファイル作成/大幅変更時、エラー発生時に更新。**棚卸し（目安80行以内）:** 完了 `[x]` を除去、実装詳細は git log に委任、重複を排除、恒久的決定は CLAUDE.md に移動。

MEMORY.md（目安150行以内）: 2週間以上未使用プロジェクトを除去、CONVENTIONS 昇格済みフィードバックを除去、解決済み案件を除去。

### push 前チェック

1. SESSION.md 更新（長ければ棚卸し） 2. CLAUDE.md 更新（構造変更時のみ） 3. 4軸レビュー → commit → push。軽微な変更では 2-3 スキップ可。

| 軸 | 内容 |
|---|---|
| **整合性** | 変更ファイル間で数値・用語・参照先が一致しているか |
| **無矛盾性** | 既存ルール・テンプレートと矛盾していないか |
| **効率性** | 重複がないか。SESSION.md ~80行、MEMORY.md ~150行以内か |
| **安全性** | 個人情報・認証情報が公開リポに含まれていないか |

autocompact 復帰: CLAUDE.md → "How to Resume" → SESSION.md → 作業継続

---

## 4. Git 規約

- ブランチ `main` 統一。コミットメッセージは英語・動詞始まり
- コミット後は常に push。複数リモートがあれば全リモートに push
- セッション終了時は未コミット変更があれば commit + push
- ファイル名にバージョン番号をつけない

---

## 5. 安全規則（絶対厳守）

1. 他人のファイル削除前に確認しユーザーに提示
2. 既存データ削除時はリネーム (`mv old old.bak`) を優先提案
3. force push 禁止（必要なら `--force-with-lease`）
4. 機密情報はコミットしない。同じファイルを複数リポに置かない
5. 破壊的操作は事前にユーザー確認。自分のリポのみ操作

---

## 6. 網羅性の検証

「全部」を主張する場合、列挙の前に機械的な検証基準を定め、列挙後に照合する。
