#!/bin/bash
# memory-guard.sh — メモリファイル書き込みガード
# CONVENTIONS.md §2「記録先の判別」の機械的チェックポイント
#
# 正本: claude-config/hooks/memory-guard.sh
# setup.sh が ~/.claude/hooks/ に symlink を作成
#
# 対象: PreToolUse (Edit|Write)
# 動作: メモリディレクトリへの書き込みを exit 2 でブロック
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

# --- ブロック ---
cat >&2 << 'EOF'
BLOCKED: メモリファイルへの書き込み
CONVENTIONS.md §2「記録先の判別」を確認し、適切な書き先を選べ。
メモリはユーザー個人情報・好み・外部参照先のみ。
本当にメモリが適切か？ユーザーに確認せよ。
EOF
exit 2
