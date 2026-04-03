#!/bin/zsh
# Fix shell snapshot PATH on every new Claude Code session
# Snapshots override .zshenv, so we patch them to include full PATH
#
# FULL_PATH は環境ごとに異なる。setup.sh がインストール時に
# source ~/.zshenv && echo $PATH の結果で置換する。
# 手動設定する場合もこの値を自分の環境に合わせること。
FULL_PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

for f in ~/.claude/shell-snapshots/snapshot-*.sh; do
  if grep -q 'export PATH=/usr/bin' "$f" 2>/dev/null; then
    sed -i '' "s|export PATH=/usr/bin.*|export PATH=${FULL_PATH}|" "$f"
  fi
done
