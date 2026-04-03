# MCP 規約

MCP ツールを使うリポで適用。CLAUDE.md から参照: `~/Claude/claude-config/conventions/mcp.md`

## 共通（CONVENTIONS.md §5.7 の手順詳細）

- **確認方法**: Gmail は `gmail_get_profile`、Calendar は `gcal_list_calendars` で接続先アカウントを確認
- **複数 MCP がある場合**: セッションの deferred tools 一覧で同一サービスの MCP が何個あるか確認し、それぞれ `get_profile` を実行して UUID→アカウントの対応を把握する
- **UUID→アカウント対応表をメモリに保持**: MEMORY.md に `reference_mcp_uuid_map.md` へのポインタがなければ、全 MCP で `get_profile` を実行して作成する。既にあれば deferred tools の UUID 一覧と照合し、差分があれば更新する
- **アカウント一覧の正本**: 各 MCP 設定リポの CLAUDE.md を参照（メモリや各リポの CLAUDE.md にハードコードしない）

## MCP 設定リポの役割

MCP サーバーの認証情報やセットアップ手順を一箇所で管理するためのリポ。複数のプロジェクトが同じ MCP サーバー（Gmail、Calendar 等）を利用する場合、認証情報の管理を各プロジェクトに分散させると更新漏れや不整合が起きる。設定リポに集約することで、アカウント追加・トークン更新・サーバー移行等の変更が1箇所で完結する。

記録すべき内容:
- アカウント一覧と認証情報の保存場所
- MCP サーバーの選定理由（DESIGN.md）
- セットアップ・再認証の手順（スクリプト化推奨）
- OAuth スコープと制約
- 認証情報のバックアップ方針

MCP 設定リポは private にすること（認証情報のパスやアカウント構成を含むため）。認証情報そのものはリポ外（例: `~/.gmail-mcp/`）に置き、リポには構造とスクリプトだけを入れる。

---

## MCP で不十分な場合: API 直接アクセス

MCP ツールは個別操作に最適だが、バッチ操作（一括削除・ラベル付け・統計取得等）には向かない。Gmail MCP の `modify_email` は1件ずつだが、Gmail API の `batchModify` は1回で最大1000件を処理できる。

**基本的な考え方:** MCP サーバーが OAuth 認証情報をローカルに保持しているなら、同じ認証情報を Python（`google-api-python-client`）から直接利用できる。新規に OAuth フローを構築する必要はない。

### 使い分けの基準

| 操作 | 手段 | 理由 |
|---|---|---|
| メール1件の読み取り・返信 | MCP | 対話的操作に最適、Claude が直接呼べる |
| 一括操作（削除、ラベル付け等） | Python + API | `batchModify`/`batchDelete` で最大1000件/回 |
| 統計・分析（件数、容量等） | Python + API | `messages.list` + 集計が柔軟 |
| フィルター管理 | Python + API | MCP にフィルター API がない |

### スコープに注意

MCP サーバーが取得した OAuth トークンのスコープによって使える API が異なる:

- `gmail.modify`: `batchModify`（ラベル操作・ゴミ箱移動）は可。`batchDelete`（永久削除）は不可
- `mail.google.com`: 全 API が利用可能（フルアクセス）

スコープが足りない場合は GCP コンソールで OAuth 同意画面を更新し再認証が必要。

### 実装時の注意

- Python スクリプトがトークンを refresh した場合、access_token だけでなく **refresh_token も書き戻す**。Google が refresh_token を回転させた場合に旧トークンだけがファイルに残ると、MCP サーバーも Python スクリプトも認証不能になる
- MCP サーバーと Python スクリプトの同時実行は避ける（token refresh の競合リスク）

各ユーザーの具体的な実装（認証情報のパス、スクリプト等）は MCP 設定リポの DESIGN.md に記録すること。

## Google Calendar MCP
- 操作前にカレンダー一覧で対象カレンダーが正しいことを確認
- 共有カレンダー命名: `{共同研究者名}{自分の名字}共同研究`
- イベント作成時は日時・タイトル・参加者をユーザーに確認してから作成
