#!/bin/bash
# claude-config/setup.sh
# 新しい端末で clone 後に実行するセットアップスクリプト
#   1. CONVENTIONS.md の symlink を作成（相対パス）
#   2. Claude Code hooks をインストール（symlink + settings.json マージ）
#   3. git post-merge hook をインストール（git pull 時に hooks を自動同期）
#   4. GitHub 上の全リポを <base> 以下に clone（未取得のもののみ）
#
# 使い方:
#   mkdir -p <base> && cd <base>
#   gh repo clone <your-username>/claude-config
#   cd claude-config && ./setup.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIRNAME="$(basename "$SCRIPT_DIR")"

# --- GitHub ユーザー名を認証情報から自動検出（Step 4 で使用）---
GH_USER=$(gh api user --jq '.login' 2>/dev/null)
if [ -n "$GH_USER" ]; then
    echo "GitHub user: $GH_USER"
else
    echo "WARNING: Could not detect GitHub user. Run 'gh auth login' first."
    echo "Steps 1-3 will proceed. Step 4 (repo cloning) will be skipped."
fi

# --- OS 判定（Windows では symlink に管理者権限が必要なため cp にフォールバック）---
IS_WINDOWS=false
case "$(uname -s)" in MINGW*|CYGWIN*|MSYS*) IS_WINDOWS=true ;; esac

# --- 1. Symlink ---
echo "=== Step 1: Setting up symlinks ==="

# 相対パス: symlink とターゲットが同一ツリー (<base>/) 内
REL_TARGET="$REPO_DIRNAME/CONVENTIONS.md"
LINK="$CLAUDE_DIR/CONVENTIONS.md"

if [ "$IS_WINDOWS" = true ]; then
    # Windows: cp で同期（git pull 後の自動更新は post-merge hook が担当）
    cp -f "$SCRIPT_DIR/CONVENTIONS.md" "$LINK" || exit 1
    echo "  Copied (Windows): $LINK"
elif [ -L "$LINK" ]; then
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

# --- 1b. Install global gitignore ---
echo ""
echo "=== Step 1b: Installing global gitignore ==="

GITIGNORE_SRC="$SCRIPT_DIR/gitignore_global"
GITIGNORE_DST="$HOME/.gitignore_global"

if [ ! -f "$GITIGNORE_SRC" ]; then
    echo "  WARNING: gitignore_global not found in repo. Skipping."
else
    if [ "$IS_WINDOWS" = true ]; then
        cp -f "$GITIGNORE_SRC" "$GITIGNORE_DST"
        echo "  Copied (Windows): $GITIGNORE_DST"
    elif [ -L "$GITIGNORE_DST" ]; then
        CURRENT_TARGET="$(readlink "$GITIGNORE_DST")"
        if [ "$CURRENT_TARGET" = "$GITIGNORE_SRC" ]; then
            echo "  OK: $GITIGNORE_DST -> $CURRENT_TARGET"
        else
            echo "  UPDATE: was -> $CURRENT_TARGET"
            rm "$GITIGNORE_DST"
            ln -s "$GITIGNORE_SRC" "$GITIGNORE_DST"
        fi
    elif [ -f "$GITIGNORE_DST" ]; then
        echo "  WARNING: $GITIGNORE_DST exists as regular file. Backing up."
        mv "$GITIGNORE_DST" "$GITIGNORE_DST.bak"
        ln -s "$GITIGNORE_SRC" "$GITIGNORE_DST"
        echo "  Created: $GITIGNORE_DST -> $GITIGNORE_SRC"
    else
        ln -s "$GITIGNORE_SRC" "$GITIGNORE_DST"
        echo "  Created: $GITIGNORE_DST -> $GITIGNORE_SRC"
    fi
    # Register with git
    git config --global core.excludesfile "$GITIGNORE_DST"
    echo "  Set git config --global core.excludesfile = $GITIGNORE_DST"
fi

# --- 2. Install hooks ---
# Step 1 の失敗で Step 2-4 が止まらないよう、ここから先はエラーを個別処理
echo ""
echo "=== Step 2: Installing Claude Code hooks ==="

HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

# 期待する hook 定義（settings.json にマージする内容）
# hook を追加・削除する場合はここと HOOK_CMD の for ループを同時に更新する
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

    # symlink 作成（Windows は cp にフォールバック）
    # 絶対パス使用: ~/.claude/hooks/ と <base>/claude-config/hooks/ は
    # 異なるディレクトリツリーのため、相対パスは脆弱
    for HOOK in "$HOOKS_SRC"/*.sh; do
        [ -f "$HOOK" ] || continue
        HOOK_NAME="$(basename "$HOOK")"
        LINK="$HOOKS_DST/$HOOK_NAME"
        if [ "$IS_WINDOWS" = true ]; then
            # Windows: cp で同期（git pull 後の自動更新は post-merge hook が担当）
            cp -f "$HOOK" "$LINK"
            echo "  Copied (Windows): $HOOK_NAME"
        elif [ -L "$LINK" ]; then
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
        if [ "$IS_WINDOWS" = true ]; then
            echo "  Install with: winget install jqlang.jq"
        else
            echo "  Install with: brew install jq"
        fi
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

# hook インストールの失敗は警告のみ（Step 3-4 を止めない）
if ! install_hooks; then
    echo "  ERROR: Hook installation failed. Continuing with remaining steps."
fi

# --- 3. Install git post-merge hook ---
# git pull 後に hooks と CONVENTIONS.md を自動同期する
# Windows では symlink の代わりに cp を使うため、pull 後の再同期が必要
echo ""
echo "=== Step 3: Installing git post-merge hook ==="

GIT_HOOKS_DIR="$SCRIPT_DIR/.git/hooks"
POST_MERGE="$GIT_HOOKS_DIR/post-merge"

if [ ! -d "$GIT_HOOKS_DIR" ]; then
    echo "  ERROR: .git/hooks not found. Is this a git repo?"
else
    cat > "$POST_MERGE" << 'POST_MERGE_EOF'
#!/bin/bash
# claude-config post-merge hook
# git pull 後に ~/.claude/hooks/ と <base>/CONVENTIONS.md を自動同期
# setup.sh が生成 — 手動編集不可（再実行で上書きされる）

REPO_DIR="$(git rev-parse --show-toplevel)"
PARENT_DIR="$(dirname "$REPO_DIR")"

# --- hooks の同期（コピーの場合のみ。symlink は自動更新済み）---
HOOKS_SRC="$REPO_DIR/hooks"
HOOKS_DST="$HOME/.claude/hooks"
if [ -d "$HOOKS_SRC" ] && [ -d "$HOOKS_DST" ]; then
    for HOOK in "$HOOKS_SRC"/*.sh; do
        [ -f "$HOOK" ] || continue
        HOOK_NAME="$(basename "$HOOK")"
        DEST="$HOOKS_DST/$HOOK_NAME"
        # symlink でなければコピー（Windows の cp ファイルを更新）
        if [ -f "$DEST" ] && [ ! -L "$DEST" ]; then
            cp -f "$HOOK" "$DEST"
            echo "[claude-config] Updated hook: $HOOK_NAME"
        fi
    done
fi

# --- CONVENTIONS.md の同期（コピーの場合のみ）---
CONV_DEST="$PARENT_DIR/CONVENTIONS.md"
if [ -f "$CONV_DEST" ] && [ ! -L "$CONV_DEST" ]; then
    cp -f "$REPO_DIR/CONVENTIONS.md" "$CONV_DEST"
    echo "[claude-config] Updated: CONVENTIONS.md"
fi
POST_MERGE_EOF
    chmod +x "$POST_MERGE"
    echo "  Installed: .git/hooks/post-merge"
    echo "  git pull 後に hooks と CONVENTIONS.md が自動同期されます"
fi

# --- 4. Clone all repos ---
echo ""
echo "=== Step 4: Cloning repos ==="

if [ -z "$GH_USER" ]; then
    echo "  SKIPPED: GitHub user not detected. Run 'gh auth login' and re-run setup.sh."
elif ! command -v gh &> /dev/null; then
    echo "  SKIPPED: gh (GitHub CLI) is not installed."
    if [ "$IS_WINDOWS" = true ]; then
        echo "  Install with: winget install GitHub.cli"
    else
        echo "  Install with: brew install gh"
    fi
elif ! gh auth status &> /dev/null; then
    echo "  SKIPPED: gh is not authenticated. Run: gh auth login"
else
    echo "  User: $GH_USER"

    # Get all repo names from GitHub
    REPOS=$(gh repo list "$GH_USER" --limit 100 --json name --jq '.[].name')
    CLONED=0
    SKIPPED=0

    for REPO in $REPOS; do
        TARGET_DIR="$CLAUDE_DIR/$REPO"
        if [ -d "$TARGET_DIR" ]; then
            SKIPPED=$((SKIPPED + 1))
        else
            echo "  Cloning $GH_USER/$REPO ..."
            gh repo clone "$GH_USER/$REPO" "$TARGET_DIR" 2>&1 | sed 's/^/    /'
            CLONED=$((CLONED + 1))
        fi
    done

    echo "  Cloned: $CLONED repos"
    echo "  Skipped (already exist): $SKIPPED repos"
fi

# --- 5. Install pre-commit hook for LaTeX repos ---
# .tex or .bib を含むリポに pre-commit hook (Unicode→LaTeX 自動修正) をインストール
echo ""
echo "=== Step 5: Installing pre-commit hooks for LaTeX repos ==="

PRE_COMMIT_SRC="$SCRIPT_DIR/scripts/pre-commit-bib"

if [ ! -f "$PRE_COMMIT_SRC" ]; then
    echo "  ERROR: $PRE_COMMIT_SRC not found. Skipping."
else
    INSTALLED=0
    SKIPPED_HOOK=0

    for REPO_DIR in "$CLAUDE_DIR"/*/; do
        [ -d "$REPO_DIR/.git" ] || continue

        # LaTeX ファイルが存在するか簡易チェック
        HAS_LATEX=false
        for ext in tex bib; do
            if ls "$REPO_DIR"*."$ext" "$REPO_DIR"**/*."$ext" 2>/dev/null | head -1 | grep -q .; then
                HAS_LATEX=true
                break
            fi
        done
        [ "$HAS_LATEX" = true ] || continue

        HOOK_DST="$REPO_DIR.git/hooks/pre-commit"
        REPO_NAME="$(basename "$REPO_DIR")"

        if [ "$IS_WINDOWS" = true ]; then
            # Windows: コピー
            if [ -f "$HOOK_DST" ] && grep -q "fix-bib-unicode" "$HOOK_DST" 2>/dev/null; then
                SKIPPED_HOOK=$((SKIPPED_HOOK + 1))
            else
                if [ -f "$HOOK_DST" ]; then
                    cp "$HOOK_DST" "$HOOK_DST.bak"
                    echo "  WARNING: $REPO_NAME had existing pre-commit → backed up to .bak"
                fi
                cp -f "$PRE_COMMIT_SRC" "$HOOK_DST"
                chmod +x "$HOOK_DST"
                echo "  Installed (copy): $REPO_NAME"
                INSTALLED=$((INSTALLED + 1))
            fi
        else
            # Mac/Linux: symlink
            if [ -L "$HOOK_DST" ]; then
                CURRENT_TARGET="$(readlink "$HOOK_DST")"
                if [ "$CURRENT_TARGET" = "$PRE_COMMIT_SRC" ]; then
                    SKIPPED_HOOK=$((SKIPPED_HOOK + 1))
                else
                    echo "  UPDATE: $REPO_NAME (was -> $CURRENT_TARGET)"
                    rm "$HOOK_DST"
                    ln -s "$PRE_COMMIT_SRC" "$HOOK_DST"
                    INSTALLED=$((INSTALLED + 1))
                fi
            elif [ -f "$HOOK_DST" ]; then
                if grep -q "fix-bib-unicode" "$HOOK_DST" 2>/dev/null; then
                    # 旧バージョン（直接コピー）→ symlink に差し替え
                    rm "$HOOK_DST"
                    ln -s "$PRE_COMMIT_SRC" "$HOOK_DST"
                    echo "  Upgraded to symlink: $REPO_NAME"
                    INSTALLED=$((INSTALLED + 1))
                else
                    cp "$HOOK_DST" "$HOOK_DST.bak"
                    echo "  WARNING: $REPO_NAME had existing pre-commit → backed up to .bak"
                    ln -s "$PRE_COMMIT_SRC" "$HOOK_DST"
                    echo "  Installed (symlink): $REPO_NAME"
                    INSTALLED=$((INSTALLED + 1))
                fi
            else
                ln -s "$PRE_COMMIT_SRC" "$HOOK_DST"
                echo "  Installed (symlink): $REPO_NAME"
                INSTALLED=$((INSTALLED + 1))
            fi
        fi
    done

    echo "  Installed: $INSTALLED repos"
    echo "  Already up to date: $SKIPPED_HOOK repos"
fi

echo ""
echo "=== Done ==="
