# DESIGN — claude-config

設計判断とその理由を記録する。

---

## PATH 管理: 二層防御の設計

Claude Code の Bash ツールは起動時に生成したシェルスナップショットを source する。スナップショットの `export PATH=...` がセッション中の PATH を決定するため、ここで PATH が壊れると全コマンドに影響する。

### 根本原因と第1層（.zprofile 修正）

**判断:** `.zprofile` から `brew shellenv` を削除し、PATH 設定を `~/.zshenv` に一元化。

**Why:** macOS login shell は `.zshenv` → `/etc/zprofile` → `~/.zprofile` の順に実行する。Homebrew の推奨設定（`eval "$(brew shellenv)"`）を `.zshenv` と `.zprofile` の両方に書くと、`.zprofile` 内の `path_helper`（`PATH_HELPER_ROOT="/opt/homebrew"` 付き）が `/opt/homebrew/etc/paths`（brew の bin/sbin のみ）から PATH を再構築し、`.zshenv` の if-blocks で追加した TeX・Python 等を消す。

`/etc/zprofile` の **system** `path_helper` は `/etc/paths.d/TeX` 等を読むので、login shell でも TeX は通る。`.zprofile` で再度 brew 版を呼ぶ必要はない。

**trade-off:** `.zshenv` は全 shell type で実行されるため、non-interactive shell でも brew が PATH に入る。これは Claude Code にとっては望ましい。Terminal.app のログインシェルでも問題なし。

### 第2層（スナップショット自動パッチ）

**判断:** launchd WatchPaths を採用。PreToolUse フックは棄却。

| 方式 | Bash オーバーヘッド | 仕組み |
|---|---|---|
| PreToolUse フック | ~0.05秒/回 | 毎 Bash 呼び出しで zsh を起動しパッチ済みか確認 |
| **launchd WatchPaths** | **0秒** | スナップショット生成をディレクトリ監視で検知、自動パッチ |

**Why:** スナップショットはセッション開始時に1回だけ生成される。修正も1回でいい。毎回の Bash 呼び出しでチェックするのは設計として間違い。zsh 起動コスト（~0.03秒）はスクリプト内の最適化では消せない。

**setup.sh への組み込み:** Step 2b で launchd plist を自動インストール（macOS のみ）。冪等性あり — 既にロード済みならスキップ。

### パッチスクリプトの設計: REQUIRED_PATHS 方式

**判断:** 固定 FULL_PATH の全置換ではなく、REQUIRED_PATHS リストによる不足検出・追加方式を採用。

**Why:**
1. **旧方式の脆弱性:** `grep 'export PATH=/usr/bin'` でマッチして `sed` で全置換していたが、Claude Code v2.1.87 でスナップショットの PATH 形式が変わり（先頭が `/usr/bin` ではなくなった）、パッチが効かなくなった。
2. **FULL_PATH のメンテナンス忘れ:** FULL_PATH に TeX を書き忘れていて、パッチ自体が不完全な PATH を上書きしていた。
3. **REQUIRED_PATHS 方式の利点:** 各エントリの実在チェック付きで不足分だけ追加するため、Claude Code の形式変更に耐性がある。既存の正しいエントリを壊さない。

**メンテナンスルール:** 新しいツールをインストールして PATH に追加する場合、`fix-snapshot-path-patch.sh` の REQUIRED_PATHS 配列を更新すること。

---

## 危険コマンドのブロック: deny ルール vs PreToolUse フック

**判断:** settings.json の deny ルールのみ。フックは不要。

**Why:**
1. deny ルールはフックより先に評価される。deny で拒否されたコマンドはフックに到達しない
2. つまりフックは常に死んだコードになる
3. 0.015秒/回のオーバーヘッドに見合う価値がない

当初 dangerous-commands-guard.sh を「二重防御」として残したが、deny ルールが先に評価される以上、フックが発火する状況は存在しない。背景は conventions/shell-env.md に文書化済みなので、スクリプトとして残す理由もない。削除した。

**deny ルールのパターン選定:**
- `Bash(*tccutil*)` — 広いパターンだが、Bash で tccutil に言及する正当な用途は全て Grep/Read ツールで代替可能。実害ゼロで最大安全性。

---

## hooks/ の役割分担

| ファイル | 呼び出し元 | 役割 |
|---|---|---|
| memory-guard.sh | PreToolUse (Edit/Write) | メモリディレクトリへの書き込み前に §2 判別を強制 |
| memory-guard-bash.sh | PreToolUse (Bash) | Bash 経由のメモリ書き込みを警告（0.005秒/回） |
| fix-snapshot-path-patch.sh | launchd WatchPaths | スナップショット PATH を自動修正（Bash に介入しない） |

Bash の PreToolUse フックは memory-guard-bash.sh のみ（0.005秒/回）。
