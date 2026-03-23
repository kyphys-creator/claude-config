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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIRNAME="$(basename "$SCRIPT_DIR")"

# --- 1. Symlink ---
echo "=== Step 1: Setting up symlinks ==="

# 相対パス: symlink とターゲットが同一ツリー (~/Claude/) 内
REL_TARGET="$REPO_DIRNAME/CONVENTIONS.md"
LINK="$CLAUDE_DIR/CONVENTIONS.md"

if [ -L "$LINK" ]; then
    echo "  Symlink already exists: $LINK -> $(readlink "$LINK")"
elif [ -f "$LINK" ]; then
    echo "  WARNING: $LINK exists as a regular file."
    echo "  Back up to $LINK.bak and replace with symlink."
    mv "$LINK" "$LINK.bak" || exit 1
    ln -s "$REL_TARGET" "$LINK" || exit 1
    echo "  Created: $LINK -> $REL_TARGET"
else
    ln -s "$REL_TARGET" "$LINK" || exit 1
    echo "  Created: $LINK -> $REL_TARGET"
fi

# --- 2. Install hooks ---
# Step 1 の失敗で Step 2-3 が止まらないよう、ここから先はエラーを個別処理
echo ""
echo "=== Step 2: Installing Claude Code hooks ==="

HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

# 期待する hook 定義（settings.json にマージする内容）
# hook を追加・削除する場合はここと L132 の for ループを更新する
HOOK_ENTRIES='[
  {
    "matcher": "Edit|Write",
    "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-guard.sh"}]
  },
  {
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-guard-bash.sh"}]
  }
]'

install_hooks() {
    if [ ! -d "$HOOKS_SRC" ]; then
        echo "  No hooks directory found. Skipping."
        return 0
    fi

    mkdir -p "$HOOKS_DST"

    # symlink 作成
    # 絶対パス使用: ~/.claude/hooks/ と ~/Claude/claude-config/hooks/ は
    # 異なるディレクトリツリーのため、相対パスは脆弱
    for HOOK in "$HOOKS_SRC"/*.sh; do
        [ -f "$HOOK" ] || continue
        HOOK_NAME="$(basename "$HOOK")"
        LINK="$HOOKS_DST/$HOOK_NAME"
        if [ -L "$LINK" ]; then
            # symlink のリンク先が正しいか確認
            CURRENT_TARGET="$(readlink "$LINK")"
            if [ "$CURRENT_TARGET" = "$HOOK" ]; then
                echo "  OK: $HOOK_NAME"
            else
                echo "  UPDATE: $HOOK_NAME (was -> $CURRENT_TARGET)"
                rm "$LINK"
                ln -s "$HOOK" "$LINK"
            fi
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

    # settings.json に hooks 設定をマージ
    if ! command -v jq &> /dev/null; then
        echo "  WARNING: jq not found. Cannot merge hooks into settings.json."
        echo "  Install with: brew install jq"
        echo "  Then re-run: ./setup.sh"
        return 0
    fi

    if [ ! -f "$SETTINGS" ]; then
        echo "  Creating settings.json with hooks config."
        mkdir -p "$(dirname "$SETTINGS")"
        jq -n --argjson entries "$HOOK_ENTRIES" \
            '{hooks: {PreToolUse: $entries}}' > "$SETTINGS"
        echo "  Created: $SETTINGS"
        return 0
    fi

    # 既存 settings.json にマージ
    # hooks キーがない → 追加
    # hooks キーがある → memory-guard エントリの有無を個別チェック
    if ! jq -e '.hooks' "$SETTINGS" > /dev/null 2>&1; then
        echo "  Adding hooks config to settings.json ..."
        jq --argjson entries "$HOOK_ENTRIES" \
            '. + {hooks: {PreToolUse: $entries}}' \
            "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
        echo "  Done."
    elif ! jq -e '.hooks.PreToolUse' "$SETTINGS" > /dev/null 2>&1; then
        echo "  Adding PreToolUse hooks ..."
        jq --argjson entries "$HOOK_ENTRIES" \
            '.hooks.PreToolUse = $entries' \
            "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
        echo "  Done."
    else
        # PreToolUse が存在する場合、各 hook が含まれているか個別確認
        UPDATED=false
        for HOOK_CMD in "memory-guard.sh" "memory-guard-bash.sh"; do
            if ! jq -e --arg cmd "$HOOK_CMD" \
                '.hooks.PreToolUse[] | select(.hooks[]?.command | contains($cmd))' \
                "$SETTINGS" > /dev/null 2>&1; then
                echo "  Adding missing hook: $HOOK_CMD"
                # 対応するエントリを HOOK_ENTRIES から抽出して追加
                ENTRY=$(echo "$HOOK_ENTRIES" | jq --arg cmd "$HOOK_CMD" \
                    '[.[] | select(.hooks[]?.command | contains($cmd))][0]')
                jq --argjson entry "$ENTRY" \
                    '.hooks.PreToolUse += [$entry]' \
                    "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
                UPDATED=true
            fi
        done
        if [ "$UPDATED" = false ]; then
            echo "  All hooks already configured in settings.json."
        else
            echo "  Done."
        fi
    fi
}

# hook インストールの失敗は警告のみ（Step 3 を止めない）
if ! install_hooks; then
    echo "  ERROR: Hook installation failed. Continuing with remaining steps."
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
