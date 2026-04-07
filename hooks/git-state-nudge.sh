#!/usr/bin/env bash
# git-state-nudge.sh
#
# PostToolUse hook (Bash matcher): nudge Claude when the repo has state
# that needs attention. Two distinct cases:
#
#   (1) "Just committed but not pushed" — HEAD ahead of upstream AND last
#       commit within the last 60 seconds. Enforces CONVENTIONS §4
#       "コミット後は常に push" by surfacing a reminder right after the
#       commit, when there is no excuse to defer.
#
#   (2) "First sighting of a stale repo (within the last 4 hours)" —
#       first time Claude touches this repo within SEEN_THRESHOLD, AND
#       repo has dirty tree / ahead / behind. Catches the case where the
#       session base directory is not a git repo (e.g. ~/Claude) and
#       Claude cd's into a sub-repo that already had unresolved state at
#       session start — a gap not covered by the SessionStart-only
#       `session-git-check.sh`. The 4-hour window is a deliberate
#       cross-session choice to avoid spamming when the user opens
#       multiple short sessions in quick succession; it is NOT a strict
#       per-session check.
#
# Silent when:
#   - CWD is not a git repo
#   - Repo is clean and in sync
#   - Already nudged for the same HEAD sha (no duplicate warnings)
#   - Repo has been seen recently (within 4h) and HEAD has not advanced
#
# Design notes:
#   - This hook is intentionally fast (no `git fetch`, no network).
#     Remote-divergence detection is the SessionStart hook's job.
#   - State is kept in $HOME/.claude/state/git-nudge/ as small marker
#     files. Cross-session state is acceptable here — the goal is to
#     avoid re-nudging within minutes, not to enforce per-session
#     freshness.
#   - Output to stdout is injected into the session as context (per the
#     Claude Code hook spec for PostToolUse).
#   - Per-HEAD-sha suppression means each commit produces at most ONE
#     push reminder, no matter how many Bash calls follow.

set -euo pipefail

# Fast path: not a git repo → silent exit.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -z "$REPO_ROOT" ] && exit 0

# State directory for "seen" / "nudged" markers.
STATE_DIR="$HOME/.claude/state/git-nudge"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# SHA1 of repo path → marker filename.
if command -v shasum >/dev/null 2>&1; then
  REPO_HASH="$(printf '%s' "$REPO_ROOT" | shasum | cut -d' ' -f1)"
elif command -v sha1sum >/dev/null 2>&1; then
  REPO_HASH="$(printf '%s' "$REPO_ROOT" | sha1sum | cut -d' ' -f1)"
else
  # Last resort: use a sanitized path. Not collision-resistant but works.
  REPO_HASH="$(printf '%s' "$REPO_ROOT" | tr '/' '_')"
fi
SEEN_FILE="$STATE_DIR/$REPO_HASH.seen"
NUDGED_FILE="$STATE_DIR/$REPO_HASH.nudged"

NOW="$(date +%s)"
SEEN_THRESHOLD=14400  # 4 hours: re-warn about stale state if not seen for this long
RECENT_COMMIT_WINDOW=60  # seconds: a commit within this window triggers push reminder

# Determine if this is a "first sighting" of the repo (within SEEN_THRESHOLD).
FIRST_SIGHTING=0
if [ ! -f "$SEEN_FILE" ]; then
  FIRST_SIGHTING=1
else
  # Cross-platform mtime: BSD stat (-f %m) on macOS, GNU stat (-c %Y) on Linux.
  SEEN_MTIME="$(stat -f %m "$SEEN_FILE" 2>/dev/null || stat -c %Y "$SEEN_FILE" 2>/dev/null || echo "$NOW")"
  SEEN_AGE=$((NOW - SEEN_MTIME))
  [ "$SEEN_AGE" -gt "$SEEN_THRESHOLD" ] && FIRST_SIGHTING=1
fi

# Refresh the seen marker so subsequent calls (in this session or the next
# few hours) don't re-warn.
touch "$SEEN_FILE" 2>/dev/null || true

# Gather repo state.
UPSTREAM="$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo '')"
DIRTY_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
AHEAD=0
BEHIND=0
if [ -n "$UPSTREAM" ]; then
  AHEAD="$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)"
  BEHIND="$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)"
fi

HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || echo '')"
HEAD_TS="$(git log -1 --format=%ct HEAD 2>/dev/null || echo 0)"
HEAD_AGE=999999
[ "$HEAD_TS" -gt 0 ] && HEAD_AGE=$((NOW - HEAD_TS))

# Per-HEAD-sha suppression: if we already nudged for this exact commit, don't repeat.
ALREADY_NUDGED_SHA=""
[ -f "$NUDGED_FILE" ] && ALREADY_NUDGED_SHA="$(cat "$NUDGED_FILE" 2>/dev/null || echo '')"

# Decision logic.
RECENT_COMMIT_NUDGE=0
FIRST_SIGHTING_NUDGE=0

if [ "$AHEAD" -gt 0 ] && [ "$HEAD_AGE" -le "$RECENT_COMMIT_WINDOW" ] \
   && [ "$ALREADY_NUDGED_SHA" != "$HEAD_SHA" ]; then
  RECENT_COMMIT_NUDGE=1
fi

if [ "$FIRST_SIGHTING" -eq 1 ]; then
  if [ "$DIRTY_COUNT" -gt 0 ] || [ "$AHEAD" -gt 0 ] || [ "$BEHIND" -gt 0 ]; then
    FIRST_SIGHTING_NUDGE=1
  fi
fi

# Emit. Recent-commit nudge takes precedence (it's the more actionable case).
if [ "$RECENT_COMMIT_NUDGE" -eq 1 ]; then
  printf '[git-nudge] %s\n' "$REPO_ROOT"
  printf '  - You just committed (%ss ago); HEAD is %s commit(s) ahead of %s.\n' \
    "$HEAD_AGE" "$AHEAD" "$UPSTREAM"
  printf '  - Per CONVENTIONS §4: コミット後は常に push. Run `git push` now\n'
  printf '    unless you are intentionally stacking commits.\n'
  echo "$HEAD_SHA" > "$NUDGED_FILE" 2>/dev/null || true
  exit 0
fi

if [ "$FIRST_SIGHTING_NUDGE" -eq 1 ]; then
  printf '[git-nudge] %s (first time touching this repo within ~4h)\n' "$REPO_ROOT"
  if [ "$DIRTY_COUNT" -gt 0 ]; then
    printf '  - %s uncommitted change(s) inherited from earlier work\n' "$DIRTY_COUNT"
  fi
  if [ "$AHEAD" -gt 0 ]; then
    printf '  - AHEAD by %s commit(s) — investigate and push if appropriate\n' "$AHEAD"
  fi
  if [ "$BEHIND" -gt 0 ]; then
    printf '  - BEHIND by %s commit(s) — pull before working\n' "$BEHIND"
  fi
  printf '  - Investigate this state before starting work; do not silently overwrite or commit on top.\n'
  exit 0
fi

exit 0
