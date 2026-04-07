#!/usr/bin/env bash
# session-git-check.sh
#
# SessionStart / UserPromptSubmit hook: check git state of the current directory
# and inject a summary into the session context.
#
# Purpose: prevent "work-then-push-then-divergence" failures where the session
# starts on a stale base and discovers remote progress only at push time,
# leading to large rebase conflicts.
#
# Behavior:
#   1. If CWD is not a git repo, exit silently (no output = no injection).
#   2. Otherwise, run `git fetch` (timeout 5s), then emit a compact status line:
#      - clean / dirty
#      - commits ahead/behind remote
#      - list of new remote commits (if any)
#   3. If remote has commits the local doesn't, emit a WARNING block that
#      Claude will see as high-priority context.
#
# Design notes:
#   - Output to stdout is injected into the session as context (per Claude
#     Code hook spec for SessionStart / UserPromptSubmit).
#   - We only speak up when there's something noteworthy (dirty tree or
#     divergence). A clean, in-sync repo produces no output to avoid noise.
#   - git fetch has a hard timeout so we don't hang the session on network.

set -euo pipefail

# Fast path: not a git repo → silent exit.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
[ -z "$REPO_ROOT" ] && exit 0

# Try to fetch with a short timeout. If it fails (offline, auth issue), continue.
if command -v timeout >/dev/null 2>&1; then
  timeout 5 git fetch --quiet 2>/dev/null || true
elif command -v gtimeout >/dev/null 2>&1; then
  gtimeout 5 git fetch --quiet 2>/dev/null || true
else
  git fetch --quiet 2>/dev/null || true
fi

# Gather state.
BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo 'DETACHED')"
UPSTREAM="$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo '')"
DIRTY_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

AHEAD=0
BEHIND=0
NEW_COMMITS=""
if [ -n "$UPSTREAM" ]; then
  AHEAD="$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)"
  BEHIND="$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)"
  if [ "$BEHIND" -gt 0 ]; then
    NEW_COMMITS="$(git log --oneline "HEAD..$UPSTREAM" 2>/dev/null | head -10)"
  fi
fi

# Decide whether to emit output. Silent if clean and in sync.
NEEDS_OUTPUT=0
[ "$DIRTY_COUNT" -gt 0 ] && NEEDS_OUTPUT=1
[ "$BEHIND" -gt 0 ] && NEEDS_OUTPUT=1
[ "$AHEAD" -gt 0 ] && NEEDS_OUTPUT=1

if [ "$NEEDS_OUTPUT" -eq 0 ]; then
  exit 0
fi

# Emit a structured summary. Output to stdout is injected as session context.
printf '[git-check] %s (branch: %s)\n' "$REPO_ROOT" "$BRANCH"
if [ "$DIRTY_COUNT" -gt 0 ]; then
  printf '  - %s uncommitted change(s) in working tree\n' "$DIRTY_COUNT"
fi
if [ -n "$UPSTREAM" ]; then
  if [ "$BEHIND" -gt 0 ] && [ "$AHEAD" -gt 0 ]; then
    printf '  - DIVERGED: %s ahead, %s behind %s\n' "$AHEAD" "$BEHIND" "$UPSTREAM"
    printf '  - ⚠️  RESOLVE BEFORE WORKING: pull/rebase remote changes first\n'
  elif [ "$BEHIND" -gt 0 ]; then
    printf '  - BEHIND: %s new commit(s) on %s\n' "$BEHIND" "$UPSTREAM"
    printf '  - ⚠️  RUN `git pull` BEFORE STARTING WORK (avoid later rebase conflicts)\n'
  elif [ "$AHEAD" -gt 0 ]; then
    printf '  - AHEAD: %s local commit(s) not pushed to %s\n' "$AHEAD" "$UPSTREAM"
    printf '  - Per CONVENTIONS §3: push after each logical unit of work\n'
  fi
  if [ -n "$NEW_COMMITS" ]; then
    printf '  - New commits on remote:\n'
    printf '%s\n' "$NEW_COMMITS" | sed 's/^/      /'
  fi
else
  printf '  - No upstream tracking branch\n'
fi

exit 0
