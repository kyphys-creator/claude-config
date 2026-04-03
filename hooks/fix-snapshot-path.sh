#!/bin/zsh
# Fix shell snapshot PATH on every new Claude Code session
# Snapshots override .zshenv, so we patch them to include full PATH
#
# FULL_PATH は環境ごとに異なる。setup.sh がインストール時に
# source ~/.zshenv && echo $PATH の結果で置換する。
# 手動設定する場合もこの値を自分の環境に合わせること。
FULL_PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

# 最新のスナップショットのみパッチ（全ファイルスキャンを避けて高速化）
f=$(ls -t ~/.claude/shell-snapshots/snapshot-*.sh 2>/dev/null | head -1)
[[ -z "$f" ]] && exit 0
grep -q 'export PATH=/usr/bin' "$f" && sed -i '' "s|export PATH=/usr/bin.*|export PATH=${FULL_PATH}|" "$f"
