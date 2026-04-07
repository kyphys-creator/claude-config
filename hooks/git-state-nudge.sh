#!/usr/bin/env bash
# git-state-nudge.sh
#
# PostToolUse(Bash) hook: nudge Claude when a git repo has state needing
# attention. The hook is the SOLE git-state monitor — it subsumes the
# former SessionStart hook (`session-git-check.sh`) by performing a
# one-time `git fetch` on first-sighting of a repo, so remote-divergence
# detection still happens but without the noise of a notification on
# every session startup.
#
# Cases handled (per repo, in priority order):
#
#   (1) "Orphan tree on origin" — HEAD has NO common ancestor with @{u}.
#       This is the unambiguous signature of a re-init force-push from
#       elsewhere (the failure mode that fooled Claude on 2026-04-07 —
#       see "divergence の解釈規律" and "過去の失敗事例" sections in
#       odakin-prefs/push-workflow.md). The nudge tells Claude that
#       AHEAD commits are likely ORPHANED, not unpushed, and points to
#       the 4-query checklist there.
#       NOTE: an earlier version also detected `forced-update` in the
#       origin/<branch> reflog, but that was too eager — the reflog entry
#       persists for ~90 days even after `git reset --hard` resolves the
#       issue, causing perpetual re-warning. The merge-base check is
#       dynamic and auto-clears.
#
#   (2) "Just committed but not pushed" — HEAD ahead of upstream AND
#       last commit within the last 60 seconds. Enforces CONVENTIONS §4
#       "コミット後は常に push" by surfacing a reminder right after the
#       commit, when there is no excuse to defer.
#
#   (3) "First sighting of an out-of-sync repo (within the last 4 hours)"
#       — first time the hook sees this repo within SEEN_THRESHOLD, AND
#       AHEAD or BEHIND > 0. Catches the case where the session base
#       directory is not a git repo (e.g. ~/Claude) and Claude cd's into
#       a sub-repo that already had unresolved divergence.
#       NOTE: dirty-only first-sighting was deliberately removed for
#       noise reduction — most WIP is intentional and Claude runs
#       `git status` anyway. Only AHEAD/BEHIND warrant the warning.
#       The 4-hour window is a deliberate cross-session choice to avoid
#       spamming when the user opens multiple short sessions in quick
#       succession. On first sighting, a one-time `git fetch` (5s
#       timeout) is run so the BEHIND check sees fresh remote state.
#
# Multi-repo follow (Fix B, 2026-04-07):
#   The hook reads the bash command from the Claude Code hook protocol
#   stdin JSON and additionally checks any literal `git -C <path>` and
#   `git --git-dir=<path>` targets. Variable-substituted paths (e.g.
#   `git -C "$d"` inside a for loop) are NOT resolved — those will only
#   be checked if cwd later changes into the repo. A diagnostic line is
#   emitted when `git -C` is seen but no literal path could be
#   extracted, so Claude knows the safety net is partial for that call.
#
# Silent when:
#   - All inspected repos are clean and in sync
#   - Already nudged for the same HEAD sha (no duplicate warnings)
#   - Repo has been seen recently (within 4h) AND HEAD has not advanced
#
# Design notes:
#   - First-sighting branch does ONE `git fetch` per repo (5s timeout).
#     Subsequent calls within the 4h window skip fetch entirely → fast.
#   - State is kept in $HOME/.claude/state/git-nudge/ as small marker
#     files. Cross-session state is acceptable here — the goal is to
#     avoid re-nudging within minutes, not enforce per-session freshness.
#   - Output to stdout is injected into the session as context (per the
#     Claude Code hook spec for PostToolUse).
#   - Per-HEAD-sha suppression means each commit produces at most ONE
#     push reminder, no matter how many Bash calls follow. The
#     forced-update nudge uses a separate suffix ("-fu") so that the
#     push reminder and the forced-update warning don't shadow each
#     other for the same HEAD.

set -uo pipefail
# NOTE: deliberately NOT using `set -e`. The hook contains many `grep`
# and `git` calls that may legitimately exit non-zero (no match, no
# upstream, etc.); set -e would kill the hook on the first such call.
# Each command that needs failure handling does so explicitly.

STATE_DIR="$HOME/.claude/state/git-nudge"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

NOW="$(date +%s)"
SEEN_THRESHOLD=14400  # 4 hours
RECENT_COMMIT_WINDOW=60  # seconds

# ----------------------------------------------------------------------
# check_repo_state <repo_root> <label_prefix>
#
# Inspects the repo at <repo_root> and emits warnings to stdout for any
# of cases (1)-(3) above. <label_prefix> is prepended to the repo path
# in output (empty for cwd, "[git -C] " for follow targets).
# Returns 0 always; never fatal.
# ----------------------------------------------------------------------
check_repo_state() {
  local REPO_ROOT="$1"
  local LABEL_PREFIX="$2"

  [ -z "$REPO_ROOT" ] && return 0
  [ -d "$REPO_ROOT/.git" ] || [ -f "$REPO_ROOT/.git" ] || return 0

  # Per-repo state markers (sha1 of repo path → filename).
  local REPO_HASH
  if command -v shasum >/dev/null 2>&1; then
    REPO_HASH="$(printf '%s' "$REPO_ROOT" | shasum | cut -d' ' -f1)"
  elif command -v sha1sum >/dev/null 2>&1; then
    REPO_HASH="$(printf '%s' "$REPO_ROOT" | sha1sum | cut -d' ' -f1)"
  else
    REPO_HASH="$(printf '%s' "$REPO_ROOT" | tr '/' '_')"
  fi
  local SEEN_FILE="$STATE_DIR/$REPO_HASH.seen"
  local NUDGED_FILE="$STATE_DIR/$REPO_HASH.nudged"

  # Determine first-sighting status (within SEEN_THRESHOLD).
  local FIRST_SIGHTING=0
  if [ ! -f "$SEEN_FILE" ]; then
    FIRST_SIGHTING=1
  else
    local SEEN_MTIME
    SEEN_MTIME="$(stat -f %m "$SEEN_FILE" 2>/dev/null || stat -c %Y "$SEEN_FILE" 2>/dev/null || echo "$NOW")"
    local SEEN_AGE=$((NOW - SEEN_MTIME))
    [ "$SEEN_AGE" -gt "$SEEN_THRESHOLD" ] && FIRST_SIGHTING=1
  fi
  touch "$SEEN_FILE" 2>/dev/null || true

  # On first sighting, do a one-time `git fetch` (with short timeout).
  if [ "$FIRST_SIGHTING" -eq 1 ]; then
    if command -v timeout >/dev/null 2>&1; then
      timeout 5 git -C "$REPO_ROOT" fetch --quiet 2>/dev/null || true
    elif command -v gtimeout >/dev/null 2>&1; then
      gtimeout 5 git -C "$REPO_ROOT" fetch --quiet 2>/dev/null || true
    else
      git -C "$REPO_ROOT" fetch --quiet 2>/dev/null || true
    fi
  fi

  # Gather repo state.
  local UPSTREAM
  UPSTREAM="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo '')"
  local DIRTY_COUNT
  DIRTY_COUNT="$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  local AHEAD=0 BEHIND=0
  if [ -n "$UPSTREAM" ]; then
    AHEAD="$(git -C "$REPO_ROOT" rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)"
    BEHIND="$(git -C "$REPO_ROOT" rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)"
  fi

  # Fix A (2026-04-07, refined): detect orphan-tree only.
  # An earlier version also grep'd `git reflog -1 origin/main` for the
  # string `forced-update`, but that was too eager: the reflog entry is
  # historical and persists for ~90 days. After resolving the divergence
  # by `git reset --hard`, the warning kept firing. The `merge-base`
  # check below is dynamic — it auto-clears when state is resolved.
  # Generic ahead/behind divergence (e.g. rebase force-push that does
  # share a merge-base) is caught by case (3) first-sighting, with the
  # interpretation discipline in push-workflow.md telling Claude to run
  # the 4 queries before assuming "push 忘れ".
  local ORPHAN_TREE=0
  if [ -n "$UPSTREAM" ] && [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -gt 0 ]; then
    if ! git -C "$REPO_ROOT" merge-base HEAD "$UPSTREAM" >/dev/null 2>&1; then
      ORPHAN_TREE=1
    fi
  fi

  local HEAD_SHA HEAD_TS HEAD_AGE
  HEAD_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo '')"
  HEAD_TS="$(git -C "$REPO_ROOT" log -1 --format=%ct HEAD 2>/dev/null || echo 0)"
  HEAD_AGE=999999
  [ "$HEAD_TS" -gt 0 ] && HEAD_AGE=$((NOW - HEAD_TS))

  local ALREADY_NUDGED_SHA=""
  [ -f "$NUDGED_FILE" ] && ALREADY_NUDGED_SHA="$(cat "$NUDGED_FILE" 2>/dev/null || echo '')"

  # Decision logic — case (1) [orphan-tree] takes top priority.
  local ORPHAN_NUDGE=0
  local RECENT_COMMIT_NUDGE=0
  local FIRST_SIGHTING_NUDGE=0

  if [ "$ORPHAN_TREE" -eq 1 ] && [ "$ALREADY_NUDGED_SHA" != "${HEAD_SHA}-orphan" ]; then
    ORPHAN_NUDGE=1
  fi

  if [ "$AHEAD" -gt 0 ] && [ "$HEAD_AGE" -le "$RECENT_COMMIT_WINDOW" ] \
     && [ "$ALREADY_NUDGED_SHA" != "$HEAD_SHA" ]; then
    RECENT_COMMIT_NUDGE=1
  fi

  # Refined case (3): drop the DIRTY_COUNT clause (too noisy — most WIP
  # is intentional and Claude runs `git status` anyway). Only fire on
  # AHEAD/BEHIND, which actually warrant attention.
  if [ "$FIRST_SIGHTING" -eq 1 ]; then
    if [ "$AHEAD" -gt 0 ] || [ "$BEHIND" -gt 0 ]; then
      FIRST_SIGHTING_NUDGE=1
    fi
  fi

  # ---- Emit ----
  # Case (1): orphan-tree (highest priority). Concise — full
  # 4-query checklist lives in odakin-prefs/push-workflow.md.
  if [ "$ORPHAN_NUDGE" -eq 1 ]; then
    printf '[git-nudge] %s%s\n' "$LABEL_PREFIX" "$REPO_ROOT"
    printf '  - ORPHAN TREE: HEAD has NO common ancestor with %s\n' "$UPSTREAM"
    printf '  - Per push-workflow.md "divergence の解釈規律": run the 4 queries\n'
    printf '    BEFORE concluding "push 忘れ". Your %s AHEAD commit(s) may be ORPHANED.\n' "$AHEAD"
    echo "${HEAD_SHA}-orphan" > "$NUDGED_FILE" 2>/dev/null || true
    return 0
  fi

  # Case (2): just-committed-not-pushed.
  if [ "$RECENT_COMMIT_NUDGE" -eq 1 ]; then
    printf '[git-nudge] %s%s\n' "$LABEL_PREFIX" "$REPO_ROOT"
    printf '  - You just committed (%ss ago); HEAD is %s commit(s) ahead of %s.\n' \
      "$HEAD_AGE" "$AHEAD" "$UPSTREAM"
    if [ "$BEHIND" -gt 0 ]; then
      printf '  - DIVERGED: also %s commit(s) BEHIND %s.\n' "$BEHIND" "$UPSTREAM"
      printf '  - Run `git pull --rebase` first, then `git push`. A plain push\n'
      printf '    will be rejected as non-fast-forward.\n'
    else
      printf '  - Per CONVENTIONS §4: コミット後は常に push. Run `git push` now\n'
      printf '    unless you are intentionally stacking commits.\n'
    fi
    echo "$HEAD_SHA" > "$NUDGED_FILE" 2>/dev/null || true
    return 0
  fi

  # Case (3): first-sighting of stale state.
  if [ "$FIRST_SIGHTING_NUDGE" -eq 1 ]; then
    printf '[git-nudge] %s%s (first time touching this repo within ~4h)\n' "$LABEL_PREFIX" "$REPO_ROOT"
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
    return 0
  fi

  return 0
}

# ----------------------------------------------------------------------
# main
# ----------------------------------------------------------------------

# Read the bash command from the Claude Code hook protocol stdin JSON.
# Failures (no stdin, no jq, malformed JSON) → BASH_CMD stays empty.
BASH_CMD=""
if command -v jq >/dev/null 2>&1 && [ ! -t 0 ]; then
  STDIN_JSON="$(cat 2>/dev/null || true)"
  if [ -n "$STDIN_JSON" ]; then
    BASH_CMD="$(printf '%s' "$STDIN_JSON" | jq -r '.tool_input.command // empty' 2>/dev/null || echo '')"
  fi
fi

# Track repos already inspected so we don't double-warn for cwd + git -C
# pointing at the same place.
CHECKED_REPOS=""

# Check 1: cwd, if it's inside a git work tree.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CWD_REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
  if [ -n "$CWD_REPO" ]; then
    check_repo_state "$CWD_REPO" ""
    CHECKED_REPOS="|$CWD_REPO|"
  fi
fi

# Check 2 (Fix B, 2026-04-07): literal `git -C <path>` and
# `git --git-dir=<path>` targets in the bash command. Variable
# substitutions ($var, ${var}, "$var") are NOT resolved — those will
# fall back to cwd-based detection on later calls.
if [ -n "$BASH_CMD" ]; then
  # Match unquoted literal paths (no whitespace, no shell metachars).
  PATHS_UNQUOTED="$(printf '%s\n' "$BASH_CMD" \
    | grep -oE 'git +(-C +|--git-dir=)[A-Za-z0-9._/~-]+' 2>/dev/null \
    | sed -E 's/^git +(-C +|--git-dir=)//' || true)"
  # Match double-quoted literal paths (no $ inside, so excludes "$d").
  PATHS_QUOTED="$(printf '%s\n' "$BASH_CMD" \
    | grep -oE 'git +(-C +|--git-dir=)"[^"$]+"' 2>/dev/null \
    | sed -E 's/^git +(-C +|--git-dir=)"//; s/"$//' || true)"

  ALL_PATHS="$(printf '%s\n%s\n' "$PATHS_UNQUOTED" "$PATHS_QUOTED" | grep -v '^$' || true)"

  # NOTE: an earlier version emitted a `[git-nudge:hint]` message when
  # `git -C` was seen but no literal path could be extracted (e.g.
  # `git -C "$d"` in a loop). It was deliberately removed as noise:
  # the hint fires on every variable-substituted git -C call but never
  # corresponds to an actual problem — it's just teaching, and the user
  # only needs to be taught once. Variable-path operations are now
  # silently uncovered by the hook; the user can `cd <repo> && git ...`
  # if they want safety-net warnings.

  if [ -n "$ALL_PATHS" ]; then
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      # Tilde expansion (~/foo → $HOME/foo). Only handles leading "~/"
      # since ~user/ is rarely used in `git -C` arguments.
      case "$path" in
        "~/"*) path="${HOME}/${path:2}" ;;
        "~")   path="${HOME}" ;;
      esac
      # Resolve to absolute path.
      if [ -d "$path" ]; then
        ABS_PATH="$(cd "$path" 2>/dev/null && pwd)" || continue
      else
        continue
      fi
      # Verify it's a git repo and get the work tree root.
      git -C "$ABS_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
      REPO_ROOT="$(git -C "$ABS_PATH" rev-parse --show-toplevel 2>/dev/null || echo '')"
      [ -z "$REPO_ROOT" ] && continue
      # Skip if already checked (cwd or earlier `git -C` target).
      case "$CHECKED_REPOS" in
        *"|$REPO_ROOT|"*) continue ;;
      esac
      check_repo_state "$REPO_ROOT" "[git -C] "
      CHECKED_REPOS="${CHECKED_REPOS}${REPO_ROOT}|"
    done <<< "$ALL_PATHS"
  fi
fi

exit 0
