#!/bin/bash
# ~/Claude/claude-config/setup.sh
# 新しい端末で clone 後に実行するセットアップスクリプト
#   1. CONVENTIONS.md の symlink を作成（相対パス）
#   2. Claude Code hooks をインストール（symlink + settings.json マージ）
#   3. odakin の全リポを ~/Claude 以下に clone（未取得のもののみ）
#
# 使い方:
#   mkdir -p ~/Claude && cd ~/Claude
#   gh repo clone odakin/claude-config
#   cd claude-config && ./setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIRNAME="$(basename "$SCRIPT_DIR")"

# --- 1. Symlink ---
echo "=== Step 1: Setting up symlinks ==="

REL_TARGET="$REPO_DIRNAME/CONVENTIONS.md"
LINK="$CLAUDE_DIR/CONVENTIONS.md"

if [ -L "$LINK" ]; then
    echo "  Symlink already exists: $LINK -> $(readlink "$LINK")"
elif [ -f "$LINK" ]; then
    echo "  WARNING: $LINK exists as a regular file."
    echo "  Back up to $LINK.bak and replace with symlink."
    mv "$LINK" "$LINK.bak"
    ln -s "$REL_TARGET" "$LINK"
    echo "  Created: $LINK -> $REL_TARGET"
else
    ln -s "$REL_TARGET" "$LINK"
    echo "  Created: $LINK -> $REL_TARGET"
fi

# --- 2. Install hooks ---
echo ""
echo "=== Step 2: Installing Claude Code hooks ==="

HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$HOME/.claude/hooks"

if [ -d "$HOOKS_SRC" ]; then
    mkdir -p "$HOOKS_DST"
    for HOOK in "$HOOKS_SRC"/*.sh; do
        [ -f "$HOOK" ] || continue
        HOOK_NAME="$(basename "$HOOK")"
        LINK="$HOOKS_DST/$HOOK_NAME"
        if [ -L "$LINK" ]; then
            echo "  Symlink already exists: $LINK"
        elif [ -f "$LINK" ]; then
            echo "  WARNING: $LINK exists as regular file. Backing up."
            mv "$LINK" "$LINK.bak"
            ln -s "$HOOK" "$LINK"
            echo "  Created: $LINK -> $HOOK"
        else
            ln -s "$HOOK" "$LINK"
            echo "  Created: $LINK -> $HOOK"
        fi
    done

    # Merge hooks config into ~/.claude/settings.json
    SETTINGS="$HOME/.claude/settings.json"
    if [ -f "$SETTINGS" ]; then
        if command -v jq &> /dev/null; then
            # Check if hooks key already exists
            if jq -e '.hooks' "$SETTINGS" > /dev/null 2>&1; then
                echo "  settings.json already has hooks config. Skipping merge."
            else
                echo "  Adding hooks config to settings.json ..."
                HOOKS_CONFIG='{"hooks":{"PreToolUse":[{"matcher":"Edit|Write","hooks":[{"type":"command","command":"~/.claude/hooks/memory-guard.sh"}]}]}}'
                jq --argjson h "$HOOKS_CONFIG" '. + $h' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
                echo "  Done."
            fi
        else
            echo "  WARNING: jq not found. Cannot merge hooks into settings.json."
            echo "  Install with: brew install jq"
            echo "  Then manually add hooks config to $SETTINGS"
        fi
    else
        echo "  WARNING: $SETTINGS not found. Creating with hooks config."
        mkdir -p "$(dirname "$SETTINGS")"
        cat > "$SETTINGS" << 'SETTINGSEOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/memory-guard.sh"
          }
        ]
      }
    ]
  }
}
SETTINGSEOF
        echo "  Created: $SETTINGS"
    fi
else
    echo "  No hooks directory found. Skipping."
fi

# --- 3. Clone all odakin repos ---
echo ""
echo "=== Step 3: Cloning odakin repos ==="

if ! command -v gh &> /dev/null; then
    echo "  ERROR: gh (GitHub CLI) is not installed. Skipping repo sync."
    echo "  Install with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "  ERROR: gh is not authenticated. Run: gh auth login"
    exit 1
fi

# Get all repo names from GitHub
REPOS=$(gh repo list odakin --limit 100 --json name --jq '.[].name')
CLONED=0
SKIPPED=0

for REPO in $REPOS; do
    TARGET_DIR="$CLAUDE_DIR/$REPO"
    if [ -d "$TARGET_DIR" ]; then
        SKIPPED=$((SKIPPED + 1))
    else
        echo "  Cloning odakin/$REPO ..."
        gh repo clone "odakin/$REPO" "$TARGET_DIR" 2>&1 | sed 's/^/    /'
        CLONED=$((CLONED + 1))
    fi
done

echo ""
echo "=== Done ==="
echo "  Cloned: $CLONED repos"
echo "  Skipped (already exist): $SKIPPED repos"
