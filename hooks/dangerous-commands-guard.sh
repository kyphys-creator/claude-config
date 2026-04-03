#!/bin/bash
# dangerous-commands-guard.sh — 危険な macOS システムコマンドをブロック
#
# 対象: PreToolUse (Bash)
# 動作: tccutil reset 等の破壊的システムコマンドを検出し、実行を阻止する
#
# 背景: tccutil reset Calendar を実行し、全アプリのカレンダー権限が消失した事故
#       (2026-04-03)。ユーザーが手動で全アプリを再許可する必要があった。

INPUT=$(cat)

if command -v jq &> /dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND="$INPUT"
fi

[[ -z "$COMMAND" ]] && exit 0

# --- 危険コマンドのパターン ---

# tccutil reset: 全アプリの TCC 権限を一括削除
if echo "$COMMAND" | grep -qiE 'tccutil\s+reset'; then
    echo "BLOCKED: tccutil reset は全アプリの権限を一括削除します。個別のアプリ設定で対応してください。" >&2
    exit 2
fi

# defaults delete: システム設定の削除
if echo "$COMMAND" | grep -qiE 'defaults\s+delete\s+(/Library|com\.apple)'; then
    echo "BLOCKED: システム設定の defaults delete は破壊的です。ユーザーに確認してください。" >&2
    exit 2
fi

# csrutil: SIP の操作
if echo "$COMMAND" | grep -qiE 'csrutil\s+disable'; then
    echo "BLOCKED: SIP の無効化は許可されていません。" >&2
    exit 2
fi

# launchctl remove/unload (system): システムサービスの停止
if echo "$COMMAND" | grep -qiE 'launchctl\s+(remove|unload)\s+com\.apple'; then
    echo "BLOCKED: Apple のシステムサービスの停止は許可されていません。" >&2
    exit 2
fi

# killall で重要プロセスを殺す
if echo "$COMMAND" | grep -qiE 'killall\s+(Finder|Dock|SystemUIServer|loginwindow)'; then
    echo "BLOCKED: macOS の基幹プロセスの強制終了にはユーザー確認が必要です。" >&2
    exit 2
fi

exit 0
