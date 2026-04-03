# MCP 規約

MCP ツールを使うリポで適用。CLAUDE.md から参照: `~/Claude/claude-config/conventions/mcp.md`

## 共通（CONVENTIONS.md §5.7 の手順詳細）

- **確認方法**: Gmail は `gmail_get_profile`、Calendar は `gcal_list_calendars` で接続先アカウントを確認
- **複数 MCP がある場合**: セッションの deferred tools 一覧で同一サービスの MCP が何個あるか確認し、それぞれ `get_profile` を実行して UUID→アカウントの対応を把握する
- **UUID→アカウント対応表をメモリに保持**: MEMORY.md に `reference_mcp_uuid_map.md` へのポインタがなければ、全 MCP で `get_profile` を実行して作成する。既にあれば deferred tools の UUID 一覧と照合し、差分があれば更新する
- **アカウント一覧の正本**: 各 MCP 設定リポの CLAUDE.md を参照（メモリや CLAUDE.md にハードコードしない）
  - Gmail: `~/Claude/gmail-mcp-config/CLAUDE.md`

## Google Calendar MCP
- 操作前にカレンダー一覧で対象カレンダーが正しいことを確認
- 共有カレンダー命名: `{共同研究者名}{自分の名字}共同研究`
- イベント作成時は日時・タイトル・参加者をユーザーに確認してから作成
