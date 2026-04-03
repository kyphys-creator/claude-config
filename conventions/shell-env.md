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

## 解決策: PreToolUse フックでスナップショットをパッチ

毎回の Bash 実行前にスナップショット内の PATH を正しい値に書き換える。

### 1. フックスクリプト

`~/.claude/hooks/fix-snapshot-path.sh`:

```bash
#!/bin/zsh
# FULL_PATH は自分の環境に合わせて設定する
# 例: source ~/.zshenv && echo $PATH で確認
FULL_PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

for f in ~/.claude/shell-snapshots/snapshot-*.sh; do
  if grep -q 'export PATH=/usr/bin' "$f" 2>/dev/null; then
    sed -i '' "s|export PATH=/usr/bin.*|export PATH=${FULL_PATH}|" "$f"
  fi
done
```

`chmod +x` を忘れずに。`FULL_PATH` の値は環境ごとに異なるため、`source ~/.zshenv && echo $PATH` で確認して設定する。

### 2. settings.json への登録

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/fix-snapshot-path.sh"
          }
        ]
      }
    ]
  }
}
```

既存の Bash フックがある場合は hooks 配列に追加。

### 補足

- `.zshenv` は Terminal.app 等の通常シェルで有効なので残しておく価値がある
- `settings.json` の `env.PATH` も残しておいて損はない（将来スナップショット機構が変わった場合に効く可能性）
- PATH に追加するディレクトリが変わった場合、フックスクリプトの `FULL_PATH` を更新すること

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
