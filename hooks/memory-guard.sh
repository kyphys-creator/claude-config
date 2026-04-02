#!/bin/bash
# memory-guard.sh — メモリファイル書き込みガード
# CONVENTIONS.md §2「記録先の判別」の機械的チェックポイント
#
# 正本: claude-config/hooks/memory-guard.sh
# setup.sh が ~/.claude/hooks/ に symlink を作成
#
# 対象: PreToolUse (Edit|Write)
# 動作: メモリディレクトリへの書き込みを permissionDecision=ask でユーザー確認
#       メモリ以外は exit 0 で素通し
# 依存: jq（なければ grep フォールバック）

INPUT=$(cat)

# --- 高速パス: "memory" を含まなければ即通過 ---
[[ "$INPUT" != *"/memory/"* ]] && exit 0

# --- file_path を抽出（jq 優先、なければ grep） ---
if command -v jq &> /dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty')
else
    # jq がない環境用フォールバック: JSON から file_path を grep で抽出
    FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"$//')
fi

[[ -z "$FILE_PATH" ]] && exit 0
[[ "$FILE_PATH" != *"/.claude/projects/"*"/memory/"* ]] && exit 0

# MEMORY.md（インデックス）は通過
[[ "$FILE_PATH" == */MEMORY.md ]] && exit 0

# --- ユーザー確認 ---
cat >&2 << 'EOF'
メモリファイルへの書き込み検出。
CONVENTIONS.md §2「記録先の判別」の表を確認し、適切な書き先か確認せよ。
EOF
if command -v jq &> /dev/null; then
    jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask"}}'
else
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask"}}'
fi
exit 0
