#!/bin/bash
# memory-guard-bash.sh — Bash 経由のメモリ書き込みガード
# Edit/Write ツールのガード (memory-guard.sh) を補完
#
# 正本: claude-config/hooks/memory-guard-bash.sh
# setup.sh が ~/.claude/hooks/ に symlink を作成
#
# 対象: PreToolUse (Bash)
# 動作: コマンド文字列にメモリパスへの書き込みパターンがあれば警告
#       完全な防御は不可能（変数展開等）だが、典型的なケースを捕捉
# 依存: jq（なければ grep フォールバック）

INPUT=$(cat)

# 高速パス: memory を含まなければ即通過
[[ "$INPUT" != *"/memory/"* ]] && exit 0

# --- command を抽出（jq 優先、なければ grep） ---
if command -v jq &> /dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oE '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"$//')
fi

[[ -z "$COMMAND" ]] && exit 0

# メモリディレクトリへの書き込みパターンを検出
if echo "$COMMAND" | grep -qE '(>|tee |cp |mv |cat .*>).*/.claude/projects/.*/memory/'; then
    cat >&2 << 'EOF'
WARNING: Bash でメモリディレクトリへの書き込みを検出。
CONVENTIONS.md §2「記録先の判別」を確認せよ。
本当にメモリが適切な書き先か？
EOF
    # 警告のみ（exit 0）。Bash コマンドの誤検出リスクがあるためブロックはしない
fi

exit 0
