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
FULL_PATH="/Users/odakin/.local/bin:/Users/odakin/.npm-global/bin:/Library/TeX/texbin:/Users/odakin/Library/Python/3.9/bin:/opt/homebrew/opt/python@3.12/libexec/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

for f in ~/.claude/shell-snapshots/snapshot-*.sh; do
  if grep -q 'export PATH=/usr/bin' "$f" 2>/dev/null; then
    sed -i '' "s|export PATH=/usr/bin.*|export PATH=${FULL_PATH}|" "$f"
  fi
done
```

`chmod +x` を忘れずに。

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
