# Dropbox 共有 PDF への参照規約

複数の git リポから「Dropbox 上の特定フォルダにある参照 PDF」を、リポ内の安定した相対 path で参照したいときの標準パターン。

> 関連スクリプト:
> - `scripts/dropbox-root.sh` — Dropbox install root を OS 横断で resolve
> - `scripts/setup-dropbox-refs.sh` — 後述の YAML を読んで symlink を作る

---

## 1. What

各リポの直下に gitignored な `dropbox-refs/` symlink を置き、そのターゲットを Dropbox 内の subpath にする。スクリプト・notebook・TeX・ノートからは `./dropbox-refs/foo.pdf` という相対 path で参照する。

```
~/Claude/<repo>/
├── .gitignore        ← `/dropbox-refs` を含む
├── CLAUDE.md         ← 「共同 PDF」セクションで dropbox-refs/ の存在を案内
├── dropbox-refs/     ← per-machine の symlink (gitignored)
│                       → $DBROOT/<subpath>/
└── ...
```

`dropbox-refs/` 自体は per-machine で作られる symlink なので git には入らない。リポをチェックアウトしたユーザーは、後述の setup を経て自分の machine 用 symlink を作る。

---

## 2. Why

- Dropbox のインストール先 (`~/Dropbox`, `~/Library/CloudStorage/Dropbox`, `~/Library/CloudStorage/Dropbox-Personal`, …) は OS / Dropbox バージョン / multi-account 構成によって違う。共有リポに絶対パスを書けない
- 共同編集者ごとに Dropbox 内のフォルダ階層も違う可能性があるため、symlink の target も per-user で決める
- 「PDF 置き場の場所」をリポ自身のドキュメント (CLAUDE.md) と並べて 1 箇所に集約できる
- 同パターンを複数の共同研究で再利用できる
- リポ内で相対 path (`./dropbox-refs/...`) で参照できるので、TeX や notebook の include/load 系がそのまま動く

---

## 3. How

### 3.1 Personal layer の registry (`dropbox-collabs.yaml`)

各 user は自分の personal layer (例: `~/Claude/<personal-layer>/`) に `dropbox-collabs.yaml` を置く。Schema:

```yaml
# <personal-layer>/dropbox-collabs.yaml
# Map collaboration name → Dropbox-relative subpath. Per-user, per-machine.
collaborations:
  <repo-name>:
    subpath: <Dropbox からの相対 path>
    description: 自由記述 (optional)
```

具体例 (odakin の場合):

```yaml
collaborations:
  bayes-kai:
    subpath: Physics/ベイズ会
    description: ベイズ会論文置き場 (三島拓也との共同研究)
```

`subpath` は **その user の Dropbox install root からの相対 path**。machine / user / OS で違う可能性があるため、personal layer に閉じ込める。共有リポ (claude-config) には書かない。

`<repo-name>` は canonical 名。setup スクリプトは `<base-dir>/<repo-name>/dropbox-refs` に symlink を作るので、ローカル checkout のディレクトリ名と一致させる必要がある。

### 3.2 Setup script

```bash
~/Claude/claude-config/scripts/setup-dropbox-refs.sh \
    ~/Claude/<personal-layer>/dropbox-collabs.yaml
```

これで YAML の各 entry について `<base-dir>/<name>/dropbox-refs` symlink が `$DBROOT/<subpath>` を指すよう作成される。

特性:

- **idempotent**: 既存 symlink が同じ target なら何もしない (silent)
- **change のみ表示**: CREATED / UPDATED / WARN のみ stderr / stdout に出力
- **non-fatal warnings**: repo dir 不在 / Dropbox target 不在は WARN で skip、exit 0
- **non-clobber**: 既存の通常ファイルやディレクトリが destination にあれば error で停止 (ユーザーデータを上書きしない)

### 3.3 自動実行

`claude-config/setup.sh` は personal layer を検出した後、その中に `dropbox-collabs.yaml` があれば自動で setup-dropbox-refs.sh を呼ぶ。さらに personal layer の `.git/hooks/post-merge` に同スクリプトを呼ぶ hook を install するため、`git pull` で YAML を更新したら symlink が自動で再生成される。

新マシンへの bootstrap も既存リポでの YAML 更新も、明示的な手動 setup なしで symlink が最新に保たれる。

### 3.4 各リポへの設定

リポ root に以下を追加:

- `.gitignore` に `/dropbox-refs` 行
- `CLAUDE.md` に「共同 PDF 置き場」セクション

CLAUDE.md セクションのテンプレート:

```markdown
## 共同 PDF 置き場

参照論文 (PDF) は odakin の Dropbox `<subpath>/` にあり (collaborator
ごとの subpath は personal layer の `dropbox-collabs.yaml` を参照)。

ローカル symlink: `./dropbox-refs/`
セットアップ: `~/Claude/claude-config/scripts/setup-dropbox-refs.sh
              ~/Claude/<personal-layer>/dropbox-collabs.yaml`
詳細規約: `~/Claude/claude-config/conventions/dropbox-refs.md`
```

`<subpath>` は Dropbox 内の場所 (例: `Physics/ベイズ会`) を **collaborator 同士で合意した名前**で書く。これにより、自分用の registry を持っていない collaborator も Dropbox を Finder で navigate して同じ場所にたどり着ける。

---

## 4. Dropbox install root の解決

`scripts/dropbox-root.sh` は以下の優先順で resolve する:

1. `$DROPBOX_ROOT` 環境変数 (override)
2. `~/.dropbox/info.json` の `personal.path`
3. 同 `business.path`
4. `~/Dropbox`
5. `~/Library/CloudStorage/Dropbox`
6. `~/Library/CloudStorage/Dropbox-Personal`

すべて失敗すれば非 0 終了で stderr エラー。Linux / macOS legacy / macOS Sonoma+ / multi-account 構成を概ねカバー。Windows-WSL は (1)(4) 経由で動く。Windows-native は別途 `%APPDATA%\Dropbox\info.json` 対応が必要 (現時点 unsupported)。

---

## 5. When to use

- 共同研究のリポで、共著者と Dropbox 上の参照 PDF folder を共有しているとき
- 自分が複数 machine で同じ参照 PDF folder を使いたいとき
- 参照 PDF が大量で git に commit すると bloat する場合
- 参照 PDF が non-arXiv (preprint, 非公開 draft, journal proof, スライド等) で、何らかの共有手段が必要な場合

## 6. When NOT to use

- 参照論文がすべて arXiv 公開: refs.bib に `eprint` を入れるだけで足りる。共著者は自分で arXiv から取得すれば良い
- リポ全体を Dropbox に置きたい: forward-scattering 方式 (リポ root 自身を Dropbox の symlink にする) のほうがフィット
- 共同編集者と共有しない、純粋に個人の参照ライブラリ: per-user キャッシュ (例: `physics-research/refs/pdfs/`) で足りる
- Dropbox を使っていない user: setup script は personal layer に YAML がなければ何もしないので skip される

---

## 7. Collaborator が同じ機構を使う場合

同じパターンが任意の user に適用できる。各 user が:

1. 自分の personal layer (private repo or local-only directory) を作る
2. その中に `dropbox-collabs.yaml` を置く (canonical 名は collaborator 同士で合意、subpath は自分の Dropbox 構造に合わせる)
3. claude-config を導入し、`./setup.sh` を実行 (もしくは setup-dropbox-refs.sh を直接呼ぶ)

これだけで自分の machine に symlink が生成される。共有リポ側 (例: bayes-kai) には canonical 名 1 つだけが現れるので、collaborator 全員にとって `./dropbox-refs/` という同じ path で参照できる。

注意点:

- canonical 名は **共有リポのディレクトリ名** に合わせる (`bayes-kai` リポなら canonical 名も `bayes-kai`)
- subpath は user ごとに異なる可能性がある。共有リポの CLAUDE.md には「Dropbox 上で `<subpath>` を探してね」というヒントを書いておくと、registry を持たない collaborator もたどり着ける
- 共有 Dropbox folder の invite (Dropbox UI 上の操作) は機構の対象外。各 user が手動で accept する必要がある

---

## 8. 制約と既知の問題

- **Selective sync**: Dropbox の選択同期で folder を除外していると、target は存在するが中身が "online-only" になる。symlink は問題なく作られるが、ファイル read 時に Dropbox が download を試みる
- **同期競合**: PDF を read-only 運用すれば衝突は起きにくい。複数 user が同じ folder で notebook を同時編集する場合は別途注意 (Dropbox の conflict copy が増える)
- **Path に space や非 ASCII**: scripts は quote 厳守で対応済み。TeX 等で参照する際にも `dropbox-refs/...` (ASCII) を経由するので問題は出にくい
- **Dropbox 解約 / 移行**: 別 cloud に移った場合は `dropbox-root.sh` 相当の resolver を別途書き、setup-dropbox-refs.sh を変更するか、汎用化版に置き換える
- **Windows-native**: 現状 unsupported。WSL なら (1) DROPBOX_ROOT または (4) ~/Dropbox 経由で動く
