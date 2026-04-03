#!/bin/zsh
# Fix shell snapshot PATH on every new Claude Code session
# Snapshots override .zshenv, so we patch them to include full PATH
FULL_PATH="/Users/odakin/.local/bin:/Users/odakin/.npm-global/bin:/Library/TeX/texbin:/Users/odakin/Library/Python/3.9/bin:/opt/homebrew/opt/python@3.12/libexec/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

for f in ~/.claude/shell-snapshots/snapshot-*.sh; do
  if grep -q 'export PATH=/usr/bin' "$f" 2>/dev/null; then
    sed -i '' "s|export PATH=/usr/bin.*|export PATH=${FULL_PATH}|" "$f"
  fi
done
