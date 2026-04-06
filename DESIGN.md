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

## ARCHITECTURE.md: 必須化せず任意ファイルに留める

**判断:** §2 の必須ファイル（CLAUDE.md / SESSION.md / DESIGN.md / .gitignore）は変更しない。ARCHITECTURE.md は §2 の「任意ファイル」サブセクションに 5 行で位置づける（作る基準・作らない場合・前例リンク）。

**Why:** 2026-04-06 に全 30 リポの CLAUDE.md を行数・コードファイル数・見出しで実地レビューした結果:

1. **適用範囲が狭い:** ARCHITECTURE.md が筋良く効くのは ~3-4 リポのみ（LorentzArena / mhlw-ec-pharmacy-finder / arxiv-digest など複数レイヤを持つコードリポ）。残り 26-27 リポは LaTeX 論文・記事・データ運用・薄いスクリプト集で、構造説明が CLAUDE.md の表 1 つに収まる。必須化すると形だけのファイルが量産され、`docs/convention-design-principles.md` §3「過剰規約の害」と直接衝突する。
2. **CLAUDE.md 肥大化の救済策にならない:** 行数トップ群（300 行超 2 件、120-200 行 3 件）の見出しを精査すると、嵩を稼いでいるのは「動作プロトコル」「更新手順」「rotate チェックリスト」など**ランブック系**であって、構造説明ではない。ARCHITECTURE.md を切り出してもこれらは減らない。
3. **§2 役割定義との衝突:** CLAUDE.md の役割に「構造」が既に含まれている。ARCHITECTURE.md を必須化すると CLAUDE.md の役割定義を書き換える必要があり、既存 30 リポに波及する。
4. **実例不足:** 「ARCHITECTURE.md がなくて困った」事例は LorentzArena 1 件のみ。規約は実例から抽出するのが原則（`convention-design-principles.md` 冒頭）。1 サンプルでの規約化は早い。

**棄却した代替案:**
- *全リポ必須化:* 上記 1, 3 で却下
- *コードリポ限定で必須:* 「コードリポ」の判定基準（src/ の有無、ビルドコマンドの有無）が曖昧で揉める。CONVENTIONS の精神（機械的に適用できるルール）に合わない
- *§2 に何も書かず LorentzArena の個別最適に留める:* 同じ判断を別リポで再びするコストを避けるため、最低限の指針は明文化する

**作る基準の言語化:** 「コードリポで CLAUDE.md の構造説明が表 1 つに収まらず、ファイル名やクラス名から関係性が読み取れない場合」。否定形（作らない）も併記して、LaTeX/記事/データ運用リポで迷わないようにする。

---

## RUNBOOK 系ファイル: 規約化を待つ（実例先行）

**判断:** §2 に追加しない。`docs/runbook-*.md` 等の任意ファイル化も今は明文化しない。SESSION.md の残タスクとして「実例運用後に再検討」を残す。

**Why:** ARCHITECTURE.md の検討中に副産物として浮上した論点。CLAUDE.md 肥大化の真因がランブック系と判明したが、即規約化すべきではない:

1. **境界が曖昧:** データ運用リポの「一括更新手順」（150 行近いスクリプト群）、設定リポの secret rotate チェックリスト、multi-agent-shogun の Communication Protocol — これらは粒度・性質が大きく異なる。「ランブック」という単一概念で括れるか実例で確かめる必要がある。
2. **既に CLAUDE.md で動いている:** 上記はいずれも CLAUDE.md に書かれた状態で運用が回っている。困っているわけではない。先に規約を作ると「切り出すべきか否か」の再判断コストが発生する。
3. **ARCHITECTURE.md と同じ轍:** 1 サンプルでの規約化を避ける原則を、自分自身でもう一度踏んではいけない。実例 2-3 件で運用してから抽象化する。

**次の判断トリガー:** いずれかのリポで CLAUDE.md からランブックを切り出す具体的ニーズが出たとき（例: 一括更新手順が拡張されてさらに肥大化、または別端末からの実行で手順が壊れる事故）。そのとき DESIGN.md にこの欄を更新し、規約化判断を再開する。

---

## CONVENTIONS.md §2 記録判別表: user-specific instance を除去

**判断:** §2 の「記録先の判別」表から「特定ドメインの参照データを特定の private リポの管理ツールに送る」instance 行を削除。同等のルールは個人規約リポ (odakin-prefs) に専用ファイルとして移管した。

**Why:** 元の行は表の他の行 (普遍的な情報種別 → 記録先の対応) と性質が異なり、user-specific な instance を universal table に混入させていた。匿名化するだけでは構造的問題が残る:

1. **table の同質性が崩れる:** 他の 6 行はどれも universal な対応 (例: 「設計判断 → DESIGN.md」)。問題の行だけが特定のリポ・特定のスクリプトを名指ししており、claude-config を clone する他の利用者には無意味
2. **public リポに private リポ名が露出:** 名指しされていた管理リポは private。claude-config の安全規則 (CLAUDE.md) は非公開リポ名のコミットを禁じており、その例外リストにも該当しない
3. **一般化しても情報密度が失われる:** 「ドメイン固有の参照データは専用ツール参照」のような曖昧化では実用価値ゼロ

**移管先の選定:** 候補は (a) odakin-prefs/CLAUDE.md (private cross-machine 個人規約), (b) memory (~/.claude/...), (c) 該当 private リポの CLAUDE.md。

- (b) memory はルール定義の置き場ではない (`docs/convention-design-principles.md` §5)
- (c) 該当 private リポの CLAUDE.md に置くと、同ドメインの他リポで作業中にこの横断ルールが見えない (リポ単位のスコープでは届かない)
- (a) odakin-prefs は cross-machine な個人規約のために設計された場所であり、最も適合する

**odakin-prefs 側の構造:** odakin-prefs/CLAUDE.md は「1 ルール = 1 ファイル」「テーブルに載っているファイルだけが実効的」という原則を持つ。これに従い専用ファイルを新規作成し、CLAUDE.md のテーブルに追記した。

---

## ~/Claude/CLAUDE.md の symlink 化 (完了 2026-04-06)

**実行結果:** 戦略 **(b) 個別ファイル化 + symlink 置換** を採用して実行完了。`~/Claude/CLAUDE.md` は `odakin-prefs/CLAUDE.md` への symlink に置換済み。

**移管マッピング:**

| 旧 `~/Claude/CLAUDE.md` のセクション | 移管先 |
|---|---|
| 作業ディレクトリ宣言 | `odakin-prefs/project-structure.md` |
| プロジェクト構成ルール | `odakin-prefs/project-structure.md` |
| preview_start リンク出力ルール | `odakin-prefs/project-structure.md` (bundle) |
| ユーザー情報 (氏名・所属・メール) | `odakin-prefs/user-profile.md` |
| CONVENTIONS.md 参照リスト | `odakin-prefs/CLAUDE.md` 本体「規約参照」セクションに統合 |

**bundling 判断の根拠 (詳細は odakin-prefs DESIGN.md 該当セクション):** 「1 ルール = 1 ファイル」の厳格適用は 1 行ファイルを生む。pragmatic relaxation として「関連密接かつ合計 10 行未満」のルールは bundle 可とした。`project-structure.md` がこれに該当 (作業ディレクトリ + 配置 + preview)。

**setup.sh step 7 (CLAUDE.md user-facing 番号) への影響:** 既存設計のまま機能する。新規端末では `odakin-prefs` clone 後、setup.sh 内の Step 5a (`setup.sh` L460-481) が `~/Claude/CLAUDE.md` (target なし or regular file) を symlink に置換する。本セッションの symlink は手動 `rm + ln -s` で作成したため、setup.sh 自身の冪等性 (regular file 上書きパス) の実地検証は次回 setup.sh 実行時に行う (TODO)。

**今回の手動操作:** 旧 regular file は `~/Claude/CLAUDE.md.pre-symlink-backup` に退避後、symlink 経由読み込みを確認したうえで削除済み。

---

## claude-config git history scrubbing (確定: 見送り 2026-04-06)

**判断:** 見送り。HEAD クリーン化で実用的な対応は完了したと見なす。下記の trade-off 分析を踏まえてユーザーと再確認のうえ確定。

**経緯:** 2026-04-06 に CONVENTIONS.md §2 記録判別表から特定 private リポを名指しした行を削除した。HEAD は既にクリーンだが、過去の commit には削除前の状態が残っている (`git log -p CONVENTIONS.md` で特定可能)。

**手段の選択肢:**

- `git filter-repo --replace-text` (推奨。filter-branch より高速・安全)
- `git filter-branch --tree-filter` (古い方法、どこでも動く)
- BFG Repo-Cleaner (file 単位の置換に便利、文字列単位はやや弱い)

**リスクと制約:**

1. **force-push が必要**: 公開リポへの force-push は安全規則 §5.3 で原則禁止。`--force-with-lease` でも履歴書き換えには変わりない
2. **他端末 clone との不整合**: 他のマシン (別 PC) で同じリポを clone している場合、pull が失敗するか歴史が分岐する。再 clone が必要
3. **外部キャッシュは消えない**: GitHub 自身の cache, fork, web view, archive.org, Wayback Machine, GitHub Code Search index, 各種 mirror に既に取り込まれている場合は除去できない。force-push しても "完全削除" は達成不可能
4. **commit hash の変動**: 外部から該当 commit を参照しているリンク (PR コメント、blog post、issue 等) はリンク切れになる

**価値の評価:**

- HEAD は既にクリーンで、public リポを訪れる人は基本的に HEAD のみ閲覧する → 実用上の安全性は確保済み
- 「string が史的に存在した」という事実は変えられない → scrubbing しても完全な秘匿は不可能
- リスク (force-push, 他端末との不整合, 外部キャッシュ残留) が利得 (HEAD 以外の閲覧経路の遮断) を上回る

**実行を再検討するトリガー:**

- 文字列検索などで該当 private リポ名が外部から実際に発見・言及された
- "完全クリーン" に強い意向が新たに発生した
- 上記以外のタイミングでは検討しない (スコープ外)

---

## CONVENTIONS.md / conventions/ 内の自己言及的 odakin 記述 (確定: 現状維持 2026-04-06)

**判断:** 現状維持。意図的設計として残す。下記の trade-off 分析を踏まえてユーザーと再確認のうえ確定。

**該当箇所** (2026-04-06 grep 結果):

| 場所 | 内容 | 意図 |
|---|---|---|
| `CONVENTIONS.md` L10 | `/Users/odakin/` をパス例として明示 | パス記述ルールの**反例**として使用。「ユーザー固有絶対パスを書かない」原則を可視化 |
| `conventions/latex.md` L16-18 | JHEP.bst「個人的好み」、setup.sh の odakin-only 自動インストール | .bst 自体が public リポ内に置かれており、由来 (個人趣味) を honest に文書化 |
| `conventions/research-email.md` L41 | `assignee: odakin | collaborator_id` 例示 | スキーマ説明の例示。匿名化すると意味が伝わらない |
| `conventions/scheduled-tasks.md` L58 | 「現運用者(odakin)の全マシン」 | パス hardcode を選んだ理由として、現運用者が 1 人であることを正直に文書化 |

**性質:** これらは「private 情報の leak」ではなく「設計選択」。claude-config は odakin の流儀を public に展示するリポであり、運用者として odakin を例示することは設計目的と整合する。

**削除を検討すべきトリガー:**

- odakin 以外の co-maintainer が増えた
- claude-config を template として使う他ユーザーが現れた (流儀の押し付けを避けたい)
- 上記以外のタイミングでは現状維持

**棄却した代替案:**

- *全てを完全匿名化:* 設計判断の why が伝わらず、文書としての価値が下がる
- *private 化:* claude-config を public にしている目的 (公開展示 + 他ユーザーへの参考) と矛盾

---

## DESIGN.md と EXPLORING.md の分離（2026-04-06）

### What

- `CONVENTIONS.md §2` の DESIGN.md 定義を「**決定した**設計判断（defer 含む）」に絞る
- 任意ファイル `EXPLORING.md` を新設（ARCHITECTURE.md と同じ「任意ファイル」扱い）。未決定の思考・代替案・option space の棚卸し用
- 境界判別・lifecycle・3 カテゴリ分析・棄却した代替案の詳細は `docs/convention-design-principles.md §6` を正本とする（重複を避けるためここでは書かない）

### Why（ここに書く最小限）

原則・3 カテゴリ分析の全文は `docs/convention-design-principles.md §6` 参照。**このファイルには決定固有の context だけを残す**:

- **トリガー**: LorentzArena 2+1/DESIGN.md が 500+ 行に肥大化し、「残存する設計臭 defer」（決定記録）とスマホ UI 思考メモ（未決定）を同時に書く必要が生じた場面
- **気づき**: DESIGN.md が既に「決定記録 / 未決定探索 / メタ決定（defer）」の 3 カテゴリ dumping ground になっていた（2+1 の用語再考セクションが前例として既に存在）
- **選択**: 2 ファイル分割（決定 vs 探索）。3 ファイル分割やタグ付けは却下した（詳細は principles §6）

### 初回適用

- **2026-04-06**: `LorentzArena/2+1/EXPLORING.md` 新規作成。スマホ UI の設計思考を収容
- **2026-04-07** (4 軸レビュー追加修正): 初回適用リポ内で用語再考セクションが DESIGN.md に orphan bullets として残っていた問題を検出し、同日 `2+1/EXPLORING.md` に migrate した
  - 経緯: `88ed267` (2026-04-06) で残存する設計臭セクション追加時に `### 用語の再考` ヘッダーが誤って置換され、bullets が orphan 化していた。cadf135 の defer 拡張でさらに文脈から離れた
  - 判断: 「retroactive migration はしない」の対象は **他リポ**。初回適用リポ内の既存 (b) コンテンツは EXPLORING.md 新設タイミングで同時 migrate するのが自然（1 件だけ例外にすると規約 purity を自ら毀損）

### 適用方針（簡潔版）

詳細は `docs/convention-design-principles.md §6` 参照。要点:

- **他リポへの retroactive migration はしない**: 既存の既存 DESIGN.md は触らない
- **新規探索が発生したリポから順に導入**: 上記 LorentzArena 2+1 が初回
- **小リポ・決定しか書かないリポでは不要**: EXPLORING.md は任意ファイル

---

## hooks/ の役割分担

| ファイル | 呼び出し元 | 役割 |
|---|---|---|
| memory-guard.sh | PreToolUse (Edit/Write) | メモリディレクトリへの書き込み前に §2 判別を強制 |
| memory-guard-bash.sh | PreToolUse (Bash) | Bash 経由のメモリ書き込みを警告（0.005秒/回） |
| fix-snapshot-path-patch.sh | launchd WatchPaths | スナップショット PATH を REQUIRED_PATHS 方式で自動補完（Bash に介入しない） |

Bash の PreToolUse フックは memory-guard-bash.sh のみ（0.005秒/回）。
