# シェル環境（Claude Code + macOS）

## 問題

Claude Code（デスクトップ版）は起動時にシェルスナップショット（`~/.claude/shell-snapshots/`）を生成し、Bash ツール実行のたびにそれを source する。スナップショットには `export PATH=...` が含まれ、`.zshenv` 等で設定した PATH を上書きする。

デスクトップ版は Finder/Dock から起動するため、macOS デフォルトの最小 PATH（`/usr/bin:/bin:/usr/sbin:/sbin`）しか持たない。結果、Homebrew・TeX Live 等のコマンドが Bash ツールから使えない。

### 試して効かなかった方法

| 方法 | 結果 |
|---|---|
| `~/.zshenv` に PATH 設定 | スナップショットの `export PATH=...` が後から上書き |
| `launchctl setenv PATH ...` | Claude.app のスナップショット生成に反映されない |
| `settings.json` の `env.PATH` | スナップショットが優先される |
| LaunchAgent plist | 同上 |

## 解決策: launchd WatchPaths でスナップショットを自動パッチ

スナップショットディレクトリの変更を launchd が検知し、即座にパッチする。Bash 呼び出しには一切介入しない（オーバーヘッド 0秒）。

### 棄却した方法: PreToolUse フック

当初は PreToolUse フックで毎回パッチしていたが、zsh 起動コスト ~0.03秒が毎 Bash 呼び出しにかかる。セッション中にスナップショットは変わらないので、毎回チェックは設計として間違い。

### 1. パッチスクリプト

`~/.claude/hooks/fix-snapshot-path-patch.sh`:

```bash
#!/bin/zsh
sleep 1  # スナップショット生成完了を待つ
# FULL_PATH は自分の環境に合わせて設定する
FULL_PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

for f in ~/.claude/shell-snapshots/snapshot-*.sh; do
  if grep -q 'export PATH=/usr/bin' "$f" 2>/dev/null; then
    sed -i '' "s|export PATH=/usr/bin.*|export PATH=${FULL_PATH}|" "$f"
  fi
done
```

### 2. launchd エージェント

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
        <string>$HOME/.claude/shell-snapshots</string>
    </array>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/.claude/hooks/fix-snapshot-path-patch.sh</string>
    </array>
</dict>
</plist>
```

`launchctl load ~/Library/LaunchAgents/com.user.claude-snapshot-fix.plist` で有効化。

### 補足

- `.zshenv` は Terminal.app 等の通常シェルで有効なので残しておく価値がある
- PATH に追加するディレクトリが変わった場合、パッチスクリプトの `FULL_PATH` を更新すること

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
