# claude-config

Shared conventions and bootstrap tooling for managing multiple projects with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

> **日本語版**: [README.ja.md](README.ja.md)

## Why This Exists

Claude Code's context window is finite. Long conversations get compressed (autocompact), and without a structured recovery path, work-in-progress state is lost. Across many projects, this problem multiplies: each project needs the same discipline, but maintaining it by hand is error-prone.

This repo solves that with:

- **CONVENTIONS.md** — A single set of rules for what to write where, so autocompact recovery always works
- **conventions/** — Domain-specific rules (LaTeX, MCP, shared repos) loaded only when relevant
- **setup.sh** — One-command bootstrap: symlinks, hooks, permissions, and repo cloning
- **hooks/** — Claude Code hooks that mechanically enforce the conventions
- **scripts/** — Git pre-commit hooks (LaTeX Unicode auto-fix)

One authoritative copy of the rules, symlinked into your workspace. Every project follows the same protocol without duplication.

## Quick Start

```bash
mkdir -p ~/Claude && cd ~/Claude
gh repo clone <your-username>/claude-config
cd claude-config && ./setup.sh
```

`setup.sh` does:

1. Symlinks `CONVENTIONS.md` into the parent directory
2. Installs global gitignore (`~/.gitignore_global` → `claude-config/gitignore_global`)
3. Installs Claude Code hooks (memory-guard) + merges settings into `~/.claude/settings.json`
4. *(macOS only)* Installs launchd agent for automatic shell-snapshot PATH fix
5. Configures Claude Code permissions — auto-allows safe tools (Bash, Read, Edit, Write, Glob, Grep, WebFetch, WebSearch)
6. Installs a git `post-merge` hook for auto-sync on `git pull`
7. Clones all your GitHub repos (skips existing)
   - *(optional)* Detects a personal layer (a sibling directory with a `.claude-personal-layer` marker file) and links `<base>/CLAUDE.md` to it. See [`docs/personal-layer.md`](docs/personal-layer.md)
   - *(optional)* If the personal layer contains `dropbox-collabs.yaml`, runs `scripts/setup-dropbox-refs.sh` to create `<base>/<repo>/dropbox-refs` symlinks pointing into your Dropbox install, and installs a `post-merge` hook in the personal layer so subsequent `git pull` regenerates them. See [`conventions/dropbox-refs.md`](conventions/dropbox-refs.md)
8. Installs pre-commit hooks for LaTeX repos (Unicode → LaTeX auto-fix in `.tex`/`.bib`)
9. *(optional)* Unlocks git-crypt encrypted repos (only if `~/.secrets/git-crypt.key` exists)
10. *(optional)* Installs Hammerspoon config for Claude for Mac Cmd+Q quit prevention (only if Hammerspoon is installed)

> **`<base>`** = the parent directory where you cloned claude-config (e.g. `~/Claude/`). Detected automatically by `setup.sh`.

On Windows (MSYS/Cygwin), symlinks are replaced with file copies, and the `post-merge` hook keeps them in sync.

## Repo Structure

```
~/Claude/                       # recommended base directory
├── CONVENTIONS.md → claude-config/CONVENTIONS.md  (symlink)
├── claude-config/              # this repo
│   ├── CLAUDE.md               # project-specific instructions
│   ├── SESSION.md              # current work state and tasks
│   ├── CONVENTIONS.md          # shared rules (single source of truth)
│   ├── README.md               # this file (English)
│   ├── README.ja.md            # Japanese version
│   ├── setup.sh                # bootstrap script
│   ├── DESIGN.md               # design rationale (Why / alternatives / tradeoffs)
│   ├── conventions/            # domain-specific rules
│   │   ├── shared-repo.md      # shared repos: Git workflow, .gitignore, ~ paths
│   │   ├── latex.md            # LaTeX: equation safety, compiler, JHEP.bst, pre-commit
│   │   ├── mcp.md              # MCP/GCal: pre-operation checks, naming conventions
│   │   ├── research-email.md   # research email classification and logging
│   │   ├── collaborators.md    # collaborator DB conventions
│   │   ├── scheduled-tasks.md  # Scheduled Tasks: SKILL.md dual structure, sync rules
│   │   ├── substack.md         # Substack: Markdown → rich text conversion
│   │   ├── shell-env.md        # shell env: PATH snapshot fix, macOS deny rules
│   │   └── dropbox-refs.md     # per-repo dropbox-refs/ symlink to a Dropbox shared PDF folder
│   ├── hooks/                  # Claude Code hooks
│   │   ├── memory-guard.sh             # Edit/Write guard
│   │   ├── memory-guard-bash.sh        # Bash guard (warning only)
│   │   ├── git-state-nudge.sh          # PostToolUse(Bash): unpushed commit nudge + first-sighting fetch
│   │   └── fix-snapshot-path-patch.sh  # PATH snapshot fix (called by launchd)
│   ├── scripts/                # Git hooks + helpers
│   │   ├── fix-bib-unicode.py      # Unicode → LaTeX conversion
│   │   ├── pre-commit-bib          # pre-commit hook shell wrapper
│   │   ├── dropbox-root.sh         # cross-OS Dropbox install root resolver
│   │   └── setup-dropbox-refs.sh   # build dropbox-refs symlinks from a personal-layer YAML
│   ├── hammerspoon/            # Hammerspoon config (macOS)
│   │   └── init.lua                # Claude Cmd+Q quit prevention (eventtap)
│   ├── docs/
│   │   ├── usage-tips.md           # usage tips (English)
│   │   ├── usage-tips.ja.md        # usage tips (Japanese)
│   │   ├── git-crypt-guide.md      # git-crypt encryption guide (English)
│   │   └── git-crypt-guide.ja.md   # git-crypt encryption guide (Japanese)
│   ├── gitignore_global        # → ~/.gitignore_global (symlink)
│   ├── gfm-rules.md            # CJK markdown reference
│   └── LICENSE                  # MIT
├── project-a/
├── project-b/
└── ...
```

Each project's `CLAUDE.md` references `CONVENTIONS.md` for shared rules and `conventions/*.md` for domain-specific rules. Domain rules are loaded on demand, not on every session.

## What's Inside

### CONVENTIONS.md

Core rules that apply to all projects. See [CONVENTIONS.md](CONVENTIONS.md) for full details.

### conventions/

Domain-specific rules, loaded only when relevant:

- **[shared-repo.md](conventions/shared-repo.md)** — Rules for repos shared with collaborators: Git workflow guards, `.gitignore` requirements, `~` path prohibition
- **[latex.md](conventions/latex.md)** — LaTeX-specific rules: equation safety (no AI edits without approval), compiler settings, `JHEP.bst`, pre-commit hook for Unicode cleanup
- **[mcp.md](conventions/mcp.md)** — MCP connector rules: pre-operation account verification, Google Calendar naming conventions
- **[research-email.md](conventions/research-email.md)** — Research email classification and logging conventions
- **[collaborators.md](conventions/collaborators.md)** — Collaborator DB schema and update rules
- **[scheduled-tasks.md](conventions/scheduled-tasks.md)** — Scheduled Tasks: SKILL.md dual structure, sync rules
- **[substack.md](conventions/substack.md)** — Substack: Markdown → rich text conversion workflow
- **[shell-env.md](conventions/shell-env.md)** — Shell environment: PATH snapshot fix for Claude Code desktop, macOS deny rules for dangerous commands
- **[dropbox-refs.md](conventions/dropbox-refs.md)** — Per-repo `dropbox-refs/` symlink to a Dropbox shared PDF folder, resolved per-machine via a personal-layer YAML registry. Used for collaborations where reference PDFs live in Dropbox at user-dependent absolute paths

### Hooks: memory-guard

The conventions define a decision table for where information belongs (CONVENTIONS.md §2):

| Information type | Destination |
|-----------------|-------------|
| User preferences, feedback, external references | Memory (`~/.claude/`) |
| Current work state, tasks | SESSION.md |
| Permanent specs, structure | CLAUDE.md |
| Design rationale | DESIGN.md |
| Cross-project rules | CONVENTIONS.md |
| Derivable from code/git | Don't write it |

The memory-guard hooks enforce this mechanically:

- **`memory-guard.sh`** (Edit/Write) — Prompts for user confirmation on writes to the memory directory, ensuring the storage destination is correct. MEMORY.md (the index) is allowed through.
- **`memory-guard-bash.sh`** (Bash) — Warns on shell commands that write to the memory directory. Warning only, since shell command detection has false-positive risk.

Both are installed as symlinks by `setup.sh`, so updates propagate on `git pull`.

### Scripts

- **`fix-bib-unicode.py`** — Converts non-LaTeX Unicode characters (em-dashes, curly quotes, etc.) to LaTeX equivalents in `.tex` and `.bib` files
- **`pre-commit-bib`** — Git pre-commit hook that runs the above script automatically. Installed by `setup.sh` for repos containing LaTeX files.

### Encryption

- **[git-crypt-guide.md](docs/git-crypt-guide.md)** — How to encrypt sensitive repos with git-crypt: setup, key management, `.gitattributes` configuration, multi-repo key sharing, and troubleshooting. `setup.sh` auto-unlocks repos when a key is present.

### Other files

- **`gitignore_global`** — Global gitignore covering OS files, TeX intermediates, editor files. Symlinked to `~/.gitignore_global` by `setup.sh`.
- **`gfm-rules.md`** — GitHub Flavored Markdown rendering issues with CJK text: bold markers (`**`) breaking adjacent to CJK characters, and workarounds.

## Core Concepts

### CLAUDE.md vs SESSION.md

- **CLAUDE.md** = "How to work on this project" — structure, build commands, how to resume. Updated rarely.
- **SESSION.md** = "Where we are right now" — current task, progress, recent decisions. Updated continuously.

This separation is the foundation of autocompact recovery: CLAUDE.md is always loaded, its "How to Resume" section points to SESSION.md, and SESSION.md has everything needed to continue.

### Push-before-check

Before every `git push`, verify that SESSION.md and CLAUDE.md reflect reality. The protocol includes a 4-axis review (consistency, non-contradiction, efficiency, safety). This single habit prevents documentation drift — and in practice, it catches something almost every time.

### Autocompact recovery

When Claude Code's context is compressed:

1. CLAUDE.md is auto-loaded (always in context)
2. "How to Resume" section directs Claude to read SESSION.md
3. SESSION.md provides current state, remaining tasks, and recent decisions
4. Work continues seamlessly

SESSION.md accuracy is the critical path. If it's stale, recovery fails.

### Safety guardrails

See [CONVENTIONS.md §5](CONVENTIONS.md) and [conventions/latex.md](conventions/latex.md) for LaTeX-specific rules.

## Usage Tips

Practical patterns from running 20+ projects with this system:

- **English**: [docs/usage-tips.md](docs/usage-tips.md)
- **日本語**: [docs/usage-tips.ja.md](docs/usage-tips.ja.md)

## Customization

Fork this repo and edit CONVENTIONS.md to match your workflow. The conventions are written in Japanese, but the structure is language-agnostic. `setup.sh` auto-detects your GitHub user — works as-is.

## License

MIT
