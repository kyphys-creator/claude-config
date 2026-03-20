---
title: "Claude Codeが全部忘れる問題を解決する―複数プロジェクト運用の設計パターン"
emoji: "🧠"
type: "tech"
topics: ["ClaudeCode", "AI", "開発環境", "プロジェクト管理", "Claude"]
published: false
---

# はじめに

Claude Code を本格的に使い始めると、すぐにぶつかる壁がある。

**「さっきまで完璧に理解してたのに、突然全部忘れた」**

これは Claude Code の **autocompact**（コンテキスト圧縮）によるもので、会話が長くなると古い部分が自動的に要約・圧縮される。プロジェクトの構造、さっき決めた方針、作業の進捗――すべてが消える。

1つのプロジェクトでもつらいのに、複数プロジェクトを並行して進めていると状況はさらに悪化する。「あのプロジェクトのあのファイルの続き、どこまでやったっけ？」に答えられなくなる。

この記事では、10以上のプロジェクトを Claude Code で同時運用する中で確立した設計パターンを紹介する。核となるアイデアは単純だ:

:::message
**Claude に「記憶」を外部ファイルとして持たせ、復帰手順を自動化する。**
:::

リポジトリは公開しているので、そのまま使える。

https://github.com/odakin/claude-config

---

# 問題: Claude Code は「揮発性」である

Claude Code の `CLAUDE.md` は会話開始時に自動で読み込まれる。だから「このプロジェクトはこういう構造で、こう動かす」という情報は保持できる。

しかし、以下の情報は `CLAUDE.md` に書くべきではない:

- **今どのタスクをやっているか**（毎回変わる）
- **どこまで進んだか**（分単位で変わる）
- **さっき何を決めたか**（会話中に決まる）

これらを `CLAUDE.md` に書くと、すぐに陳腐化する。かといって書かないと、autocompact で消える。

**解決策: ファイルを2つに分ける。**

---

# 核心: CLAUDE.md と SESSION.md の分離

```
my-project/
├── CLAUDE.md      ← 「どうやるか」（永続的）
├── SESSION.md     ← 「今どこにいるか」（揮発的）
└── ...
```

## CLAUDE.md = プロジェクトの取扱説明書

構造変更時にだけ更新する。内容:

- プロジェクト概要
- ディレクトリ構成
- ビルド・実行コマンド
- **How to Resume**（復帰手順 ← これが最重要）

```markdown
## How to Resume
1. SESSION.md を読む → 現在状態と次のステップを把握
2. 「次のステップ」に従って作業継続
3. 不明点はユーザーに確認
```

## SESSION.md = 作業のライブログ

タスクが進むたびに更新する。内容:

- 現在やっていること
- タスク進捗（チェックリスト）
- 直近の決定事項
- 次のステップ

```markdown
# My Project Session

## 現在の状態
**作業中**: APIエンドポイントのリファクタリング

### タスク進捗
- [x] 既存エンドポイントの洗い出し
- [x] 共通ミドルウェアの抽出
- [ ] エラーハンドリングの統一 ← **ここから再開**

## 次のステップ
1. src/handlers/ 以下の try-catch を共通エラーハンドラーに置換
2. テスト実行して regression がないか確認
```

## なぜこれが効くのか

autocompact が起きると:

1. Claude は `CLAUDE.md` を自動で読む（常にコンテキスト内）
2. 「How to Resume」セクションが「SESSION.md を読め」と指示する
3. `SESSION.md` を読むと、現在の状態・進捗・次のアクションがわかる
4. **何事もなかったかのように作業を再開できる**

ポイントは、SESSION.md の更新を **Claude 自身に自動でやらせる** こと。「タスク完了時に SESSION.md を更新しろ」とルール化すれば、人間が手動でメモを取る必要はない。

---

# 複数プロジェクトの管理: 共通規約の一元化

プロジェクトが増えると、次の問題が出る:

- プロジェクトごとに `CLAUDE.md` のフォーマットがバラバラ
- 安全規則を全プロジェクトに書くのが面倒
- 1つのプロジェクトで学んだ教訓が他に伝播しない

**解決策: 共通規約を1つのファイルにまとめ、シンボリックリンクで全プロジェクトに配る。**

```
~/Claude/
├── CONVENTIONS.md → claude-config/CONVENTIONS.md  (symlink)
├── claude-config/          # 設定リポ
│   ├── CONVENTIONS.md      # 共通規約の正本
│   └── setup.sh            # セットアップスクリプト
├── project-a/
│   ├── CLAUDE.md           # 「~/Claude/CONVENTIONS.md 参照」+ 固有指示
│   └── SESSION.md
├── project-b/
│   ├── CLAUDE.md
│   └── SESSION.md
└── ...
```

`setup.sh` 一発で symlink 作成 + 全リポ clone が完了する:

```bash
mkdir -p ~/Claude && cd ~/Claude
gh repo clone your-username/claude-config
cd claude-config && ./setup.sh
```

## CONVENTIONS.md に入れるもの

自分の場合、以下の11セクションに整理している:

| セクション | 内容 |
|-----------|------|
| §1 リポ作成 | `gh repo create` の定型手順 |
| §2 必須ファイル | CLAUDE.md / SESSION.md / .gitignore の役割定義 |
| §3 自動更新プロトコル | SESSION.md をいつ・どう更新するかのルール |
| §4-5 テンプレート | CLAUDE.md / SESSION.md のスターターテンプレート |
| §6 .gitignore | 共通の除外パターン |
| §7 ディレクトリ命名 | `src/`, `docs/`, `tools/` 等の標準名 |
| §8 Git 規約 | コミットメッセージ、push プロトコル |
| §9 安全規則 | 破壊的操作の防止、機密情報の保護 |
| §10 網羅性の検証 | 「全部やった」と言う前の機械的チェック |
| §11 その他 | 画像出力ルール等 |

特に重要なのは **§3 自動更新プロトコル** と **§9 安全規則** だ。

---

# 自動更新プロトコル: 記憶を勝手に書かせる

SESSION.md の更新を人間がやっていたら絶対に続かない。Claude に自動でやらせる。

CONVENTIONS.md に以下のルールを書いておく:

```markdown
## 自動更新プロトコル

**人間に言われなくても自動で行う。**

### SESSION.md 更新タイミング
- タスク完了時 → `[x]` にし成果物を記録
- 重要な判断時 → 「直近の決定事項」に記録
- ファイル作成/大幅変更時 → パスと概要を記録
- エラー・ブロッカー発生時 → 問題と状態を記録
- 長い作業の区切り → 中間状態を記録（autocompact 対策）

### push 前チェック
1. SESSION.md が実態と一致しているか確認・更新
2. CLAUDE.md の更新が必要か判断
3. CLAUDE.md を更新した場合 → CONVENTIONS.md と矛盾がないか確認
4. 冗長・陳腐化・曖昧な記述がないか確認
5. commit → push
```

**「push 前チェック」がミソ** で、`git push` のたびに Claude がドキュメントの整合性を確認する。ドキュメントが実態から乖離することを構造的に防ぐ。

---

# 安全規則: AI に「やってはいけないこと」を教える

Claude Code はシェルコマンドを実行できる。つまり `rm -rf` も `git push --force` もやろうと思えばできてしまう。

以下のような安全規則を共通規約に入れておく:

```markdown
## 安全規則（絶対厳守）

1. 自分が作っていないファイルの削除前に確認
2. 既存データ削除時はリネーム (`mv old old.bak`) を優先
3. force push 禁止（必要なら `--force-with-lease`）
4. 機密情報（.env, credentials）はコミットしない
5. 破壊的操作は必ず事前にユーザー確認
6. 自分のリポのみ操作。他ユーザーのリポは触らない
```

特に注意すべきは **LaTeX を扱うプロジェクト** だ。Claude は物理の数式をハルシネーションで書き換えることがある。論文リポでは以下のルールを追加している:

```markdown
8. LaTeX の式（equation/align 環境内）は原則として変更しない。
   変更が必要な場合は必ず事前にユーザーに確認すること。
```

これは実際に起きた事故から生まれたルールだ。英語校正を頼んだら、ついでに式まで「修正」されて、一見もっともらしいが物理的に間違った式が本文に紛れ込んだ。気づかなかったら論文に載るところだった。

---

# 実践例: 10プロジェクト同時運用

現在、以下のようなプロジェクトを同時に進めている（内容はぼかしている）:

- 物理の研究論文（LaTeX）
- 記事執筆（Markdown + Zenn）
- データ分析・可視化ツール（Python + JavaScript）
- 計算ツール（Python）
- この設定リポ自体

どのプロジェクトでも、会話の冒頭で Claude は `CLAUDE.md` を読み、「How to Resume」に従って `SESSION.md` を読み、即座に前回の続きから作業を開始する。

**プロジェクトを切り替えるコスト = SESSION.md を読む時間（数秒）** だ。

## autocompact 復帰の実際のフロー

```
[コンテキスト圧縮発生]
  ↓
1. CLAUDE.md 自動読み込み（常にコンテキスト内）
  ↓
2. "How to Resume" → SESSION.md を読む
  ↓
3. SESSION.md に「ここから再開」が書いてある
  ↓
4. 何事もなかったかのように続行
```

このフローが成立するための前提条件:
- SESSION.md が **常に最新** であること
- SESSION.md の更新が **自動** であること（人間がやると漏れる）
- 「次のステップ」が **具体的** であること（「続きをやる」ではなく「src/handlers/auth.ts のエラーハンドリングを共通化する」）

---

# セットアップ手順

## 1. リポジトリをクローン

```bash
mkdir -p ~/Claude && cd ~/Claude
gh repo clone odakin/claude-config
cd claude-config && ./setup.sh
```

`setup.sh` が行うこと:
1. `~/Claude/CONVENTIONS.md` → `claude-config/CONVENTIONS.md` のシンボリックリンクを作成
2. GitHub 上の全リポを `~/Claude/` 以下にクローン

## 2. 各プロジェクトの CLAUDE.md に参照を追加

```markdown
## 規約
- `~/Claude/CONVENTIONS.md` に従う
```

## 3. SESSION.md を作成

CONVENTIONS.md §5 のテンプレートを使う。初回は手動で作成し、以降は Claude が自動更新する。

## 4. カスタマイズ

CONVENTIONS.md をフォークして、自分のワークフローに合わせて編集する。特にカスタマイズすべき箇所:

- §1: GitHub ユーザー名
- §4: CLAUDE.md テンプレート（プロジェクト構造に合わせて）
- §9: 安全規則（自分のドメインに合わせて追加）
- `setup.sh`: GitHub ユーザー名

---

# まとめ

| 問題 | 解決策 |
|------|--------|
| autocompact で進捗が消える | SESSION.md に自動記録 |
| CLAUDE.md が陳腐化する | push 前チェックで強制同期 |
| プロジェクトごとにルールがバラバラ | CONVENTIONS.md を symlink で共有 |
| Claude が危険な操作をする | 安全規則を共通規約に明記 |
| プロジェクト切り替えのコストが高い | How to Resume → SESSION.md で数秒復帰 |

核心は「**Claude 自身にドキュメントを管理させる**」という発想の転換だ。人間がメモを取るのではなく、Claude にメモを取らせる。Claude にそのメモを読ませる。このループが回り始めると、autocompact はもはや問題ではなくなる。

リポジトリ: https://github.com/odakin/claude-config

---

:::message
**補足: Claude Code の memory 機能との違い**

Claude Code には組み込みの memory 機能（`~/.claude/` 以下のファイル）もあるが、これはユーザーの好みや振る舞いの記録に向いている。プロジェクトの作業状態の管理には SESSION.md のほうが適している。理由:

- memory はプロジェクト横断的。SESSION.md はプロジェクト固有
- memory は Claude が「覚えておくべき」と判断したものだけ。SESSION.md は全進捗を体系的に記録
- memory は Git 管理されない。SESSION.md は Git で履歴が残り、他の端末と同期できる
- memory は読み込みタイミングを制御できない。SESSION.md は「How to Resume」で確実に読ませられる
:::
