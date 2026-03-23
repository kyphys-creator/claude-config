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
# 依存: jq（なければ入力全体をパターンマッチ）

INPUT=$(cat)

# 高速パス: memory を含まなければ即通過
[[ "$INPUT" != *"/.claude/projects/"*"/memory/"* ]] && exit 0

# 書き込みパターンを検出（jq でコマンドを抽出できなくても、入力全体でマッチ）
# jq がなくても INPUT 自体にコマンド文字列が含まれるため、直接検査で十分
if command -v jq &> /dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    # jq なし: 入力全体をコマンドとして扱う（誤検出は exit 0 なので無害）
    COMMAND="$INPUT"
fi

[[ -z "$COMMAND" ]] && exit 0

# メモリディレクトリへの書き込みパターンを検出
if echo "$COMMAND" | grep -qE '(>|tee |cp |mv ).*/.claude/projects/.*/memory/'; then
    cat >&2 << 'EOF'
WARNING: Bash でメモリディレクトリへの書き込みを検出。
CONVENTIONS.md §2「記録先の判別」を確認せよ。
EOF
    # 警告のみ（exit 0）。Bash コマンドの誤検出リスクがあるためブロックはしない
fi

exit 0
