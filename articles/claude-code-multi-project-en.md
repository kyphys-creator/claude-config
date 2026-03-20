---
title: "Solving Claude Code's Memory Loss ― Multi-Project Design Patterns"
emoji: "🧠"
type: "tech"
topics: ["ClaudeCode", "AI", "DeveloperTools", "ProjectManagement", "Claude"]
published: false
---

# Introduction

If you've used Claude Code seriously, you've hit this wall:

**"It understood everything perfectly a minute ago, and now it's forgotten all of it."**

This is **autocompact** — Claude Code's automatic context compression. As conversations grow, older parts are summarized and compressed. Project structure, decisions you just made, work progress — all gone.

It's painful with one project. With multiple projects in parallel, it's a disaster.

This article presents design patterns developed while running 10+ projects simultaneously with Claude Code. The core idea is simple:

:::message
**Give Claude "memory" as external files, and automate the recovery process.**
:::

The repository is public and ready to use:

https://github.com/odakin/claude-config

---

# The Problem: Claude Code Is Volatile

Claude Code's `CLAUDE.md` is automatically loaded at the start of every conversation. So "this project has this structure and runs like this" persists fine.

But these things should NOT go in `CLAUDE.md`:

- **What task you're working on** (changes every session)
- **How far you've gotten** (changes every minute)
- **What you just decided** (decided during the conversation)

Write these in `CLAUDE.md` and they go stale immediately. Don't write them anywhere, and autocompact erases them.

**The solution: split into two files.**

---

# The Core Pattern: CLAUDE.md + SESSION.md

```
my-project/
├── CLAUDE.md      ← "How to work on this" (permanent)
├── SESSION.md     ← "Where we are now" (volatile)
└── ...
```

## CLAUDE.md = The Project Manual

Updated only when the project structure changes:

- Project overview
- Directory structure
- Build/run commands
- **How to Resume** (the most important part)

```markdown
## How to Resume
1. Read SESSION.md → understand current state and next steps
2. Continue from "Next Steps"
3. Ask the user if anything is unclear
```

## SESSION.md = The Live Work Log

Updated as tasks progress:

- Current work in progress
- Task checklist
- Recent decisions
- Next steps

```markdown
# My Project Session

## Current State
**Working on**: API endpoint refactoring

### Task Progress
- [x] Inventory existing endpoints
- [x] Extract common middleware
- [ ] Unify error handling ← **resume here**

## Next Steps
1. Replace try-catch blocks in src/handlers/ with common error handler
2. Run tests to check for regressions
```

## Why This Works

When autocompact fires:

1. Claude loads `CLAUDE.md` automatically (always in context)
2. "How to Resume" tells it to read `SESSION.md`
3. `SESSION.md` provides current state, progress, and next actions
4. **Work resumes as if nothing happened**

The key insight: make Claude update SESSION.md **automatically**. When rules say "update SESSION.md after completing a task," no human note-taking is needed.

---

# Multi-Project Management: Centralized Conventions

As projects multiply, new problems emerge:

- `CLAUDE.md` format varies across projects
- Safety rules must be duplicated everywhere
- Lessons from one project don't propagate to others

**Solution: centralize conventions in one file, distribute via symlinks.**

```
~/Claude/
├── CONVENTIONS.md → claude-config/CONVENTIONS.md  (symlink)
├── claude-config/          # config repo
│   ├── CONVENTIONS.md      # single source of truth
│   └── setup.sh            # bootstrap script
├── project-a/
│   ├── CLAUDE.md           # "See ~/Claude/CONVENTIONS.md" + project-specific
│   └── SESSION.md
├── project-b/
│   ├── CLAUDE.md
│   └── SESSION.md
└── ...
```

One command sets up symlinks and clones all repos:

```bash
mkdir -p ~/Claude && cd ~/Claude
gh repo clone your-username/claude-config
cd claude-config && ./setup.sh
```

## What Goes in CONVENTIONS.md

I've organized mine into 11 sections:

| Section | Purpose |
|---------|---------|
| §1 Repo creation | Standard `gh repo create` recipe |
| §2 Required files | CLAUDE.md / SESSION.md / .gitignore role definitions |
| §3 Auto-update protocol | When and how to update SESSION.md |
| §4-5 Templates | Starter templates for CLAUDE.md and SESSION.md |
| §6 .gitignore | Common ignore patterns |
| §7 Directory naming | Standard names: `src/`, `docs/`, `tools/`, etc. |
| §8 Git conventions | Commit messages, push protocol |
| §9 Safety rules | Preventing destructive operations |
| §10 Exhaustive verification | Mechanical checks before claiming completeness |
| §11 Miscellaneous | Image output, Markdown rules |

The most critical sections are **§3 Auto-update Protocol** and **§9 Safety Rules**.

---

# Auto-Update Protocol: Making Claude Keep Its Own Notes

If humans had to maintain SESSION.md, it would never happen. Let Claude do it.

Put these rules in CONVENTIONS.md:

```markdown
## Auto-Update Protocol

**Do the following automatically, without being asked.**

### When to Update SESSION.md
- Task completion → mark `[x]`, record deliverables
- Important decisions → record in "Recent Decisions"
- File creation/major changes → record path and summary
- Errors/blockers → record problem and state
- Work milestones → record intermediate state (autocompact defense)

### Pre-Push Check
1. Verify SESSION.md matches actual state → update if not
2. Check if CLAUDE.md needs updating
3. If CLAUDE.md was updated → verify no contradictions with CONVENTIONS.md
4. Check for stale/redundant/ambiguous content
5. commit → push
```

**The "pre-push check" is the key mechanism.** Every `git push` triggers an integrity check on the documentation. Drift between docs and reality is structurally prevented.

---

# Safety Rules: Teaching AI What NOT to Do

Claude Code can execute shell commands. That means `rm -rf` and `git push --force` are possible.

Put rules like these in shared conventions:

```markdown
## Safety Rules (Absolute)

1. Confirm before deleting files you didn't create
2. Prefer rename (`mv old old.bak`) over delete
3. No force push (use `--force-with-lease` if necessary)
4. Never commit secrets (.env, credentials)
5. Always confirm before destructive operations
6. Only operate on your own repositories
```

Pay special attention to **LaTeX projects**. Claude can hallucinate equation changes. For research paper repos, I added:

```markdown
8. Do not modify LaTeX equations (equation/align environments)
   without explicit user approval.
```

This rule was born from an actual incident. I asked for English proofreading on a paper, and Claude "helpfully" corrected an equation too — producing something that looked plausible but was physically wrong. It nearly went into a submitted paper.

---

# In Practice: 10 Projects at Once

I currently run projects across these domains (details deliberately vague):

- Physics research papers (LaTeX)
- Article writing (Markdown + Zenn)
- Data analysis & visualization tools (Python + JavaScript)
- Computation tools (Python)
- This config repo itself

In every project, Claude reads `CLAUDE.md` at the start, follows "How to Resume" to `SESSION.md`, and immediately picks up where it left off.

**Context-switching cost = time to read SESSION.md (seconds).**

## The Actual Recovery Flow

```
[Context compression occurs]
  ↓
1. CLAUDE.md loaded automatically (always in context)
  ↓
2. "How to Resume" → read SESSION.md
  ↓
3. SESSION.md says exactly where to resume
  ↓
4. Work continues as if nothing happened
```

Prerequisites for this to work:
- SESSION.md is **always current**
- SESSION.md updates are **automatic** (human-maintained = guaranteed gaps)
- "Next Steps" are **specific** (not "continue working" but "refactor error handling in src/handlers/auth.ts")

---

# Setup Guide

## 1. Clone the Repository

```bash
mkdir -p ~/Claude && cd ~/Claude
gh repo clone odakin/claude-config
cd claude-config && ./setup.sh
```

`setup.sh` will:
1. Create `~/Claude/CONVENTIONS.md` symlink → `claude-config/CONVENTIONS.md`
2. Clone all your GitHub repos into `~/Claude/`

## 2. Add Convention Reference to Each Project

In each project's `CLAUDE.md`:

```markdown
## Conventions
- Follow `~/Claude/CONVENTIONS.md`
```

## 3. Create SESSION.md

Use the template from CONVENTIONS.md §5. Create it manually the first time; Claude handles all subsequent updates.

## 4. Customize

Fork the repo and edit CONVENTIONS.md for your workflow:

- §1: Your GitHub username
- §4: CLAUDE.md template for your project structure
- §9: Safety rules for your domain
- `setup.sh`: Your GitHub username

---

# Summary

| Problem | Solution |
|---------|----------|
| Autocompact erases progress | SESSION.md with auto-recording |
| CLAUDE.md goes stale | Pre-push check forces sync |
| Rules vary across projects | CONVENTIONS.md shared via symlink |
| Claude runs dangerous commands | Safety rules in shared conventions |
| High cost of project switching | How to Resume → SESSION.md (seconds) |

The core insight: **make Claude manage its own documentation**. Don't take notes for Claude — make Claude take notes for itself. Make Claude read its own notes. Once this loop starts working, autocompact stops being a problem.

Repository: https://github.com/odakin/claude-config

---

:::message
**Note: How This Differs from Claude Code's Built-in Memory**

Claude Code has a built-in memory system (`~/.claude/` files), but it serves a different purpose — recording user preferences and behavioral patterns. For project work state management, SESSION.md is more appropriate:

- Memory is cross-project; SESSION.md is project-specific
- Memory records what Claude deems worth remembering; SESSION.md systematically tracks all progress
- Memory isn't version-controlled; SESSION.md has full Git history and syncs across machines
- Memory loading timing is uncontrollable; SESSION.md is reliably loaded via "How to Resume"
:::
