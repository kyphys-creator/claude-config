# SESSION — claude-config

## 現在の状態
**完了**: secrets-config リポ作成・鍵パス移行完了、全ファイル push 済み

## 残タスク
なし

## 直近の作業（2026-04-02）

- Hammerspoon 設定追加: Claude for Mac の Cmd+Q 誤終了防止
- memory-guard.sh: `exit 2` → `permissionDecision: "ask"` に変更
- git-crypt 鍵管理を secrets-config リポに独立:
  - 鍵パスを `~/.gmail-mcp/git-crypt.key` → `~/.secrets/git-crypt.key` に移行
  - secrets-config/CLAUDE.md を鍵管理の正本に
  - 4リポの CLAUDE.md は unlock コマンド + secrets-config 参照に簡素化
  - setup.sh の鍵パスと参照先を更新
