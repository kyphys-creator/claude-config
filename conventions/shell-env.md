# シェル環境（Claude Code + macOS）

## 問題

Claude Code（デスクトップ版）は起動時にシェルスナップショット（`~/.claude/shell-snapshots/`）を生成し、Bash ツール実行のたびにそれを source する。スナップショットには `export PATH=...` が含まれ、シェル init で設定した PATH がここで確定する。

問題は二つ:

1. **`.zprofile` の二重 `brew shellenv`**: macOS login shell の起動順は `.zshenv` → `/etc/zprofile`（system `path_helper`）→ `~/.zprofile`。Homebrew の推奨設定（`eval "$(brew shellenv)"`）を `.zshenv` と `.zprofile` の両方に書くと、`.zprofile` の `path_helper`（`PATH_HELPER_ROOT="/opt/homebrew"` 付き）が PATH を再構築し、`.zshenv` の if-blocks で追加した TeX・Python 等を消す。
2. **スナップショット生成時の PATH 欠損**: 上記の結果、スナップショットに不完全な PATH が焼き込まれ、セッション中ずっと引きずる。

### macOS login shell の PATH 構築順

| 順序 | ファイル | path_helper | 読むもの |
|------|----------|-------------|----------|
| 1 | `~/.zshenv` | brew shellenv 経由 (`PATH_HELPER_ROOT=homebrew`) | `/opt/homebrew/etc/paths` のみ |
| 2 | `/etc/zprofile` | **macOS system** | `/etc/paths` + `/etc/paths.d/*`（TeX 含む） |
| 3 | `~/.zprofile` | **ここが問題だった** | 再度 `/opt/homebrew/etc/paths` のみ |

### 試して効かなかった方法

| 方法 | 結果 |
|---|---|
| `~/.zshenv` に PATH 設定 | `.zprofile` の二重 brew shellenv が上書き |
| `launchctl setenv PATH ...` | Claude.app のスナップショット生成に反映されない |
| `settings.json` の `env.PATH` | スナップショットが優先される |
| LaunchAgent plist | 同上 |

### 補足: Intel Mac での観測 (2026-04-07)

- Login shell では `.zshenv` の `/usr/local/bin` 追加は機能している (`/bin/zsh -l -c 'echo $PATH'` で確認可)
- しかし Claude Code の snapshot 生成プロセスは login shell 経路を通っていない (snapshot ファイルの `export PATH=` 行に `/usr/local/bin` が含まれない)
- 結果: **Intel Mac では第1層 (.zshenv/.zprofile 修正) は Claude Code Bash tool に対して効いておらず、第2層 (snapshot patch) が唯一の対策**
- Apple Silicon でも同様の状況だと思われる (Anthropic 側の snapshot 生成仕様)
- shell-env.md の冒頭で「第2層は防御的措置」と書いているが、実態は**主要対策**

## 解決策: 二層防御

### 第1層: `.zprofile` の修正（根本対策）

`.zprofile` から `eval "$(brew shellenv)"` を削除。PATH 設定は `~/.zshenv` に一元化する。

- `~/.zshenv` は全 shell type（login / non-login / interactive / non-interactive）で実行される
- `/etc/zprofile` の system `path_helper` が `/etc/paths.d/TeX` 等を読むので、login shell でも TeX は通る
- `.zprofile` には brew shellenv を書かない（コメントで理由を残す）

```zsh
# ~/.zprofile
# brew shellenv は ~/.zshenv で実行済み（全 shell type 対応）
# ここで二重実行すると path_helper が PATH を再構築し、
# .zshenv の if-blocks で追加した TeX, Python 等が消える問題があった
```

### 第2層: スナップショット自動パッチ（防御的措置）

第1層で解決するはずだが、Claude Code のバージョンアップでスナップショット生成方法が変わる可能性がある。launchd WatchPaths でスナップショットディレクトリを監視し、必須 PATH を補完する。

PreToolUse フックで毎回パッチする方式は棄却した（理由は DESIGN.md 参照）。

**セットアップ:** `setup.sh` の Step 2 (hooks symlink) + Step 2b (launchd plist) で自動インストールされる。以下は仕組みの説明。

#### パッチスクリプト

`~/.claude/hooks/fix-snapshot-path-patch.sh`（正本: `claude-config/hooks/`）

REQUIRED_PATHS リストで管理。各スナップショットをスキャンし、不足している PATH エントリがあれば先頭に追加する。

- ディレクトリの実在チェック付き（存在しない PATH は追加しない）
- バックスラッシュエスケープ（`\:`）とプレーン（`:`）の両形式に対応
- パターンマッチではなく不足検出方式 — Claude Code のスナップショット形式が変わっても動く

**REQUIRED_PATHS の更新:** 新しいツール（例: Ruby, Go）をインストールしたら、スクリプトの REQUIRED_PATHS 配列に追加すること。

**Intel Mac / Apple Silicon の両対応:** REQUIRED_PATHS には Apple Silicon の `/opt/homebrew/{bin,sbin}` と Intel の `/usr/local/{bin,sbin}` の **両方を併記**する。各エントリは `[ -d ]` で実在チェックされるので、該当しない側は自動的にスキップされ無害。Intel Mac で `/usr/local/bin` が抜けていると `jq` 等の brew インストール CLI が `command not found` になる事故が発生した（2026-04-07）。

**post-merge hook での即時反映:** REQUIRED_PATHS を更新して `git pull` した場合、新規スナップショットは launchd WatchPaths が捕捉するが、**既に生成済みのスナップショットには反映されない**。post-merge hook (`setup.sh` Step 4 で生成) が pull 後に `fix-snapshot-path-patch.sh` を一度実行することで既存スナップショットも即時更新される。

#### launchd エージェント

`~/Library/LaunchAgents/com.user.claude-snapshot-fix.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.claude-snapshot-fix</string>
    <key>WatchPaths</key>
    <array>
        <!-- plist は $HOME を展開しない。フルパスで記述する -->
        <string>/Users/YOUR_USERNAME/.claude/shell-snapshots</string>
    </array>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/.claude/hooks/fix-snapshot-path-patch.sh</string>
    </array>
</dict>
</plist>
```

`launchctl load ~/Library/LaunchAgents/com.user.claude-snapshot-fix.plist` で有効化。

## macOS システムコマンドの deny ルール

settings.json の `deny` に以下を設定し、破壊的な macOS システムコマンドをブロックする:

```json
"Bash(*tccutil*)",
"Bash(*defaults delete com.apple*)",
"Bash(*csrutil disable*)",
"Bash(*launchctl remove com.apple*)",
"Bash(*launchctl unload com.apple*)"
```

`Bash(*)` パターンはコマンド文字列全体にマッチするため、文字列中に含まれるだけでもブロックされる。正当な用途（grep 等）は専用ツール（Grep, Read）で代替可能なので実害なし。

**背景:** `tccutil reset Calendar` を実行して全アプリのカレンダー権限が消失する事故が発生（2026-04-03）。PreToolUse フックの `exit 2` ではブロックできなかったため、deny ルールで対応。
