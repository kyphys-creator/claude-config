#!/bin/bash
# memory-guard.sh
# メモリファイルへの書き込み前に、記録先の判別を強制する
# CONVENTIONS.md §2「記録先の判別」の機械的チェックポイント
#
# 正本: claude-config/hooks/memory-guard.sh
# setup.sh が ~/.claude/hooks/ に symlink を作成

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# メモリディレクトリへの書き込みかチェック
if [[ "$FILE_PATH" == *"/.claude/projects/"*"/memory/"* ]]; then
  # MEMORY.md 自体のインデックス更新は許可
  if [[ "$FILE_PATH" == */MEMORY.md ]]; then
    exit 0
  fi

  cat >&2 << 'EOF'
BLOCKED: メモリファイルへの書き込み

§2 記録先の判別を実行せよ:
  - 全プロジェクト共通の規約 → CONVENTIONS.md
  - プロジェクトの現在状態 → SESSION.md
  - 永続的な仕様・手順 → CLAUDE.md
  - 設計判断の理由 → DESIGN.md
  - git log で導出可能 → 書かない
  - 上記のいずれでもない → メモリ（ユーザー情報・好み・外部参照先のみ）

本当にメモリが適切な書き先か？ユーザーに確認せよ。
EOF
  exit 2
fi

exit 0
