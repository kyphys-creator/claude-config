#!/bin/bash
# claude-config/setup.sh
# 新しい端末で clone 後に実行するセットアップスクリプト
#   1.  CONVENTIONS.md の symlink を作成（相対パス）
#   1b. グローバル gitignore をインストール（~/.gitignore_global に symlink）
#   2.  Claude Code hooks をインストール（symlink + settings.json マージ）
#   2b. launchd エージェントをインストール（スナップショット PATH 自動修正、macOS のみ）
#   3.  Claude Code パーミッション設定（安全なツールを自動許可）
#   4.  git post-merge hook をインストール（git pull 時に hooks を自動同期）
#   5.  GitHub 上の全リポを <base> 以下に clone（未取得のもののみ）
#   5b. git-crypt 暗号化リポを自動 unlock（鍵があれば）
#   6.  LaTeX リポに pre-commit hook をインストール（Unicode→LaTeX 自動修正）
#   6b. JHEP.bst を texmf-local にインストール（全リポからグローバル利用）
#   7.  Hammerspoon 設定をインストール（Claude Cmd+Q 誤終了防止、macOS のみ）
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

# --- 2b. Install launchd agent for snapshot PATH fix (macOS only) ---
# fix-snapshot-path-patch.sh を自動実行する launchd エージェントをインストール
PLIST_LABEL="com.user.claude-snapshot-fix"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

if [ "$(uname -s)" = "Darwin" ] && [ -f "$HOOKS_DST/fix-snapshot-path-patch.sh" ]; then
    echo ""
    echo "=== Step 2b: Installing launchd agent for snapshot PATH fix ==="

    PATCH_SCRIPT="$HOOKS_DST/fix-snapshot-path-patch.sh"
    SNAPSHOT_DIR="$HOME/.claude/shell-snapshots"

    if launchctl list "$PLIST_LABEL" &>/dev/null; then
        echo "  OK: $PLIST_LABEL already loaded."
    else
        mkdir -p "$(dirname "$PLIST_DST")"
        cat > "$PLIST_DST" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>WatchPaths</key>
    <array>
        <string>$SNAPSHOT_DIR</string>
    </array>
    <key>ProgramArguments</key>
    <array>
        <string>$PATCH_SCRIPT</string>
    </array>
</dict>
</plist>
PLIST_EOF
        launchctl load "$PLIST_DST" 2>&1
        if launchctl list "$PLIST_LABEL" &>/dev/null; then
            echo "  Installed and loaded: $PLIST_DST"
        else
            echo "  WARNING: Failed to load $PLIST_LABEL"
        fi
    fi
fi

# --- 3. Configure permissions ---
# 安全なツールを自動許可し、非破壊的操作のたびに確認を求めないようにする
echo ""
echo "=== Step 3: Configuring Claude Code permissions ==="

SAFE_TOOLS='["Bash", "Read", "Edit", "Write", "Glob", "Grep", "WebFetch", "WebSearch"]'

configure_permissions() {
    if ! command -v jq &> /dev/null; then
        echo "  WARNING: jq not found. Cannot configure permissions."
        return 0
    fi

    if [ ! -f "$SETTINGS" ]; then
        echo "  Creating settings.json with permissions config."
        mkdir -p "$(dirname "$SETTINGS")"
        jq -n --argjson tools "$SAFE_TOOLS" \
            '{permissions: {allow: $tools, deny: []}}' > "$SETTINGS"
        echo "  Created: $SETTINGS"
        return 0
    fi

    # permissions キーがない → 追加
    if ! jq -e '.permissions' "$SETTINGS" > /dev/null 2>&1; then
        echo "  Adding permissions config ..."
        jq --argjson tools "$SAFE_TOOLS" \
            '. + {permissions: {allow: $tools, deny: []}}' \
            "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
        echo "  Done."
    elif ! jq -e '.permissions.allow' "$SETTINGS" > /dev/null 2>&1; then
        echo "  Adding permissions.allow ..."
        jq --argjson tools "$SAFE_TOOLS" \
            '.permissions.allow = $tools' \
            "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
        echo "  Done."
    else
        # allow が存在する場合、不足しているツールを追加
        UPDATED=false
        for TOOL in $(echo "$SAFE_TOOLS" | jq -r '.[]'); do
            if ! jq -e --arg t "$TOOL" '.permissions.allow | index($t)' "$SETTINGS" > /dev/null 2>&1; then
                echo "  Adding missing permission: $TOOL"
                jq --arg t "$TOOL" \
                    '.permissions.allow += [$t]' \
                    "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
                UPDATED=true
            fi
        done
        if [ "$UPDATED" = false ]; then
            echo "  All safe tools already permitted."
        else
            echo "  Done."
        fi
    fi
}

if ! configure_permissions; then
    echo "  ERROR: Permission configuration failed. Continuing with remaining steps."
fi

# --- 4. Install git post-merge hook ---
# git pull 後に hooks と CONVENTIONS.md を自動同期する
# Windows では symlink の代わりに cp を使うため、pull 後の再同期が必要
echo ""
echo "=== Step 4: Installing git post-merge hook ==="

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

# --- JHEP.bst の同期（texmf-local にインストール済みの場合）---
JHEP_SRC="$REPO_DIR/JHEP.bst"
if [ -f "$JHEP_SRC" ] && command -v kpsewhich &> /dev/null; then
    TEXMF_LOCAL="$(kpsewhich -var-value TEXMFLOCAL 2>/dev/null)"
    BST_DST="$TEXMF_LOCAL/bibtex/bst/local/JHEP.bst"
    if [ -n "$BST_DST" ] && [ -f "$BST_DST" ]; then
        if ! diff -q "$JHEP_SRC" "$BST_DST" > /dev/null 2>&1; then
            GH_LOGIN="$(gh api user --jq '.login' 2>/dev/null)"
            if [ "$GH_LOGIN" = "odakin" ]; then
                if cp -f "$JHEP_SRC" "$BST_DST" 2>/dev/null; then
                    texhash "$TEXMF_LOCAL" 2>/dev/null
                    echo "[claude-config] JHEP.bst updated in texmf-local."
                else
                    echo "[claude-config] JHEP.bst updated. Run:"
                    echo "  sudo cp $JHEP_SRC $BST_DST && sudo texhash"
                fi
            else
                echo "[claude-config] JHEP.bst updated. To sync:"
                echo "  sudo cp $JHEP_SRC $BST_DST && sudo texhash"
            fi
        fi
    fi
fi
POST_MERGE_EOF
    chmod +x "$POST_MERGE"
    echo "  Installed: .git/hooks/post-merge"
    echo "  git pull 後に hooks と CONVENTIONS.md が自動同期されます"
fi

# --- 5. Clone all repos ---
echo ""
echo "=== Step 5: Cloning repos ==="

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

# --- 5b. Unlock git-crypt repos ---
# git-crypt + 鍵が両方ある場合のみ実行（なければサイレントスキップ）
GIT_CRYPT_KEY="$HOME/.secrets/git-crypt.key"

if command -v git-crypt &> /dev/null && [ -f "$GIT_CRYPT_KEY" ]; then
    echo ""
    echo "=== Step 5b: Unlocking git-crypt repos ==="
    UNLOCKED=0
    SKIPPED_CRYPT=0
    # .gitattributes に git-crypt 設定があるリポを自動検出
    for REPO_DIR in "$CLAUDE_DIR"/*/; do
        [ -d "$REPO_DIR/.git" ] || continue
        [ -f "$REPO_DIR/.gitattributes" ] || continue
        grep -q "git-crypt" "$REPO_DIR/.gitattributes" 2>/dev/null || continue
        REPO_NAME="$(basename "$REPO_DIR")"
        if (cd "$REPO_DIR" && git-crypt status 2>/dev/null | grep -q "encrypted:"); then
            echo "  Unlocking $REPO_NAME ..."
            (cd "$REPO_DIR" && git-crypt unlock "$GIT_CRYPT_KEY" 2>&1 | sed 's/^/    /')
            UNLOCKED=$((UNLOCKED + 1))
        else
            SKIPPED_CRYPT=$((SKIPPED_CRYPT + 1))
        fi
    done
    echo "  Unlocked: $UNLOCKED repos"
    echo "  Already unlocked: $SKIPPED_CRYPT repos"
fi

# --- 6. Install pre-commit hook for LaTeX repos ---
# .tex or .bib を含むリポに pre-commit hook (Unicode→LaTeX 自動修正) をインストール
echo ""
echo "=== Step 6: Installing pre-commit hooks for LaTeX repos ==="

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

# --- 6b. Install JHEP.bst to texmf-local (optional) ---
# JHEP.bst (modified ver. 2.18, note 有効化) を texmf-local にインストール
# odakin: 自動インストール / 他ユーザー: オプション表示のみ
JHEP_SRC="$SCRIPT_DIR/JHEP.bst"

if [ -f "$JHEP_SRC" ]; then
    # texmf-local のパスを検出
    TEXMF_LOCAL=""
    if command -v kpsewhich &> /dev/null; then
        TEXMF_LOCAL="$(kpsewhich -var-value TEXMFLOCAL 2>/dev/null)"
    elif [ -d "/usr/local/texlive/texmf-local" ]; then
        TEXMF_LOCAL="/usr/local/texlive/texmf-local"
    fi

    if [ -n "$TEXMF_LOCAL" ]; then
        BST_DIR="$TEXMF_LOCAL/bibtex/bst/local"
        BST_DST="$BST_DIR/JHEP.bst"
        NEEDS_UPDATE=false

        if [ -f "$BST_DST" ] && diff -q "$JHEP_SRC" "$BST_DST" > /dev/null 2>&1; then
            : # already up to date
        else
            NEEDS_UPDATE=true
        fi

        if [ "$NEEDS_UPDATE" = true ]; then
            echo ""
            echo "=== Step 6b: JHEP.bst (texmf-local) ==="
            if [ "$GH_USER" = "odakin" ]; then
                # 自分の端末: 自動インストール試行
                mkdir -p "$BST_DIR" 2>/dev/null
                if cp -f "$JHEP_SRC" "$BST_DST" 2>/dev/null; then
                    echo "  Installed: $BST_DST"
                    if command -v texhash &> /dev/null; then
                        texhash "$TEXMF_LOCAL" 2>&1 | sed 's/^/    /'
                    fi
                else
                    echo "  JHEP.bst needs update. Run:"
                    echo "    sudo cp $JHEP_SRC $BST_DST && sudo texhash"
                fi
            else
                # 他ユーザー: オプション表示のみ
                echo "  Optional: JHEP.bst (modified ver. 2.18, note enabled) is available."
                echo "  To install globally for BibTeX:"
                echo "    sudo mkdir -p $BST_DIR"
                echo "    sudo cp $JHEP_SRC $BST_DST"
                echo "    sudo texhash"
            fi
        fi
    fi
fi

# --- 7. Install Hammerspoon config ---
# Hammerspoon がインストール済みの場合のみ実行（なければサイレントスキップ）
HS_SRC="$SCRIPT_DIR/hammerspoon/init.lua"
HS_DIR="$HOME/.hammerspoon"
HS_DST="$HS_DIR/init.lua"

if [ "$(uname -s)" != "Darwin" ] || [ ! -d "/Applications/Hammerspoon.app" ]; then
    : # macOS 以外 or Hammerspoon 未インストール → サイレントスキップ
elif [ ! -f "$HS_SRC" ]; then
    : # init.lua がリポにない → スキップ
else
    echo ""
    echo "=== Step 7: Installing Hammerspoon config ==="
    mkdir -p "$HS_DIR"
    if [ -L "$HS_DST" ]; then
        CURRENT_TARGET="$(readlink "$HS_DST")"
        if [ "$CURRENT_TARGET" = "$HS_SRC" ]; then
            echo "  OK: $HS_DST -> $CURRENT_TARGET"
        else
            echo "  UPDATE: was -> $CURRENT_TARGET"
            rm "$HS_DST"
            ln -s "$HS_SRC" "$HS_DST"
            echo "  Created: $HS_DST -> $HS_SRC"
        fi
    elif [ -f "$HS_DST" ]; then
        echo "  WARNING: $HS_DST exists as regular file. Backing up."
        mv "$HS_DST" "$HS_DST.bak"
        ln -s "$HS_SRC" "$HS_DST"
        echo "  Created: $HS_DST -> $HS_SRC"
    else
        ln -s "$HS_SRC" "$HS_DST"
        echo "  Created: $HS_DST -> $HS_SRC"
    fi
fi

echo ""
echo "=== Done ==="
