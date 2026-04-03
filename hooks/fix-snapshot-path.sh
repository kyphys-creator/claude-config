#!/bin/zsh
# Fix shell snapshot PATH on every new Claude Code session
# Snapshots override .zshenv, so we patch them to include full PATH
#
# セッション中に1回だけ実行。パッチ済みならセンチネルで即終了。
# セッション開始時刻をキーにして、新セッションでは再実行。

# セッション内で最も古い snapshot ファイルの inode をキーにする
f=$(ls -t ~/.claude/shell-snapshots/snapshot-*.sh 2>/dev/null | head -1)
[[ -z "$f" ]] && exit 0

SENTINEL="/tmp/.claude-snap-$(stat -f%i "$f" 2>/dev/null || stat -c%i "$f" 2>/dev/null)"
[[ -f "$SENTINEL" ]] && exit 0

FULL_PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

grep -q 'export PATH=/usr/bin' "$f" && sed -i '' "s|export PATH=/usr/bin.*|export PATH=${FULL_PATH}|" "$f"
touch "$SENTINEL"
