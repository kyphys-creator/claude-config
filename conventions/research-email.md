# 研究メール規約

研究共同研究のメール通信を管理するリポで適用。CLAUDE.md から参照: `~/Claude/claude-config/conventions/research-email.md`

## メール分類

受信メールを以下の基準で分類する:

| 分類 | 条件 | 処理先 |
|------|------|--------|
| 研究メール | 送信者が `research-collab/collaborators.yaml` に登録 **または** 件名が既知プロジェクトに関連 | `research-collab/threads/{project}.yaml` |
| 事務メール | 大学事務・委員会・人事・学生対応 | `email-office/TODO.yaml` |
| その他 | 上記以外 | 通常対応（必要に応じて分類） |

## スレッド記録ルール

### 記録するもの
- 共同研究者との往復メール
- 論文投稿・レフェリーレポート関連
- 学会招待・講演依頼（研究関連）
- 研究に関する議論・質問

### 記録しないもの
- 一方的な通知メール（ML配信、学会ニュース等）
- スパム・広告

### スレッド記録の書式

```yaml
- thread_id: "Gmail thread ID"    # gmail_read_thread で再取得可能
  subject: "件名"
  participants: [collaborator_id]  # collaborators.yaml の id
  account: lab | cis | personal   # どの Gmail アカウントか
  started: YYYY-MM-DD
  last_message: YYYY-MM-DD
  status: active | waiting | resolved
  summary: |
    スレッドの要約（数行）
  action_items:
    - description: "アクション内容"
      assignee: odakin | collaborator_id
      status: pending | done | waiting
      due: YYYY-MM-DD | null
      completed: YYYY-MM-DD | null
```

### status の使い分け
- **active**: やり取りが進行中
- **waiting**: 相手の返信待ち
- **resolved**: 議論終了、アクション完了

## セッション開始時の手順

プロジェクトリポで作業開始する際:
1. `research-collab/threads/{project}.yaml` を読む
2. status が active/waiting のスレッドを報告
3. 未完了の action_items を報告
4. Gmail MCP で新着メールをチェック（共同研究者からのもの）

## メール送信後の記録

Claude がメールを送信（またはドラフト作成）した場合:
1. 該当スレッドの `last_message` を更新
2. `summary` に送信内容の要約を追記
3. 関連する action_items の status を更新
