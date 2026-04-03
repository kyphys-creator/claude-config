#!/bin/zsh
# Claude Code のシェルスナップショットを自動パッチ
# launchd WatchPaths から呼ばれる。Bash フックではない。
#
# スナップショット生成完了を待ってからパッチする。
sleep 1

FULL_PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

for f in ~/.claude/shell-snapshots/snapshot-*.sh; do
  if grep -q 'export PATH=/usr/bin' "$f" 2>/dev/null; then
    sed -i '' "s|export PATH=/usr/bin.*|export PATH=${FULL_PATH}|" "$f"
  fi
done
