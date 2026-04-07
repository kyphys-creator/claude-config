#!/bin/zsh
# Claude Code のシェルスナップショットの PATH を自動パッチ
# launchd WatchPaths から呼ばれる（~/.claude/shell-snapshots を監視）
#
# 問題: Claude Code がスナップショット生成時に shell init を走らせるが、
# .zprofile の brew shellenv 二重実行等で PATH が不完全になることがある。
# このスクリプトは必須 PATH エントリを補完する。
#
# スナップショット生成完了を待ってからパッチ
sleep 1

# 必須 PATH エントリ（存在チェックして追加）
# Intel Mac (/usr/local) と Apple Silicon (/opt/homebrew) の両方を列挙。
# 存在チェックで該当しない方は自動的にスキップされる。
REQUIRED_PATHS=(
  "/Library/TeX/texbin"
  "/opt/homebrew/opt/python@3.12/libexec/bin"
  "$HOME/Library/Python/3.9/bin"
  "$HOME/.local/bin"
  "$HOME/.npm-global/bin"
  "/opt/homebrew/bin"
  "/opt/homebrew/sbin"
  "/usr/local/bin"
  "/usr/local/sbin"
)

for f in ~/.claude/shell-snapshots/snapshot-*.sh; do
  [ -f "$f" ] || continue

  current_path=$(grep '^export PATH=' "$f" | sed 's/^export PATH=//' | sed 's/\\:/:/g')
  [ -z "$current_path" ] && continue

  modified=false
  for p in "${REQUIRED_PATHS[@]}"; do
    # ディレクトリが実在し、かつスナップショットの PATH に含まれていなければ追加
    if [ -d "$p" ] && ! echo "$current_path" | tr ':' '\n' | grep -qxF "$p"; then
      current_path="$p:$current_path"
      modified=true
    fi
  done

  if $modified; then
    # バックスラッシュエスケープ版とプレーン版の両方に対応
    escaped_path=$(echo "$current_path" | sed 's/:/\\:/g')
    if grep -q '\\:' "$f"; then
      sed -i '' "s|^export PATH=.*|export PATH=${escaped_path}|" "$f"
    else
      sed -i '' "s|^export PATH=.*|export PATH=${current_path}|" "$f"
    fi
    echo "$(date): Patched $f (added missing paths)" >> /tmp/claude-snapshot-fix.log
  fi
done
