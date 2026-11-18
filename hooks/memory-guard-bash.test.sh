#!/usr/bin/env bash
# memory-guard-bash.test.sh — memory-guard-bash.sh (Bash 用、 この fork は警告のみの版) の self-test (hermetic)
#
# 正本: claude-config/hooks/memory-guard-bash.test.sh
# 実行: bash hooks/memory-guard-bash.test.sh (run-all-checks.sh が自動発見)
#
# この fork は upstream の deny 版でなく警告のみの版の hook を使う。 hook は判定
# (permissionDecision) を一切返さず、 redirect / tee / cp / mv による memory への
# 書き込みを見つけたら stderr に警告を出すだけ (exit 0)。
# 象限: warn (memory への書き込み) / quiet (read 系・非 memory)。 どちらも判定は無し。

set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/memory-guard-bash.sh"
[ -f "$HOOK" ] || { echo "FAIL: hook not found: $HOOK"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }

pass=0; fail=0; results=()

MEM="/home/tester/.claude/projects/-home-tester-work/memory"

mk_bash() { # <command>
  jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'
}

assert() { # <label> <expect: warn|quiet> <command>
  local label="$1" expect="$2" json out err rc got
  json="$(mk_bash "$3")"
  err="$(printf '%s' "$json" | bash "$HOOK" 2>&1 >/dev/null)"; rc=$?
  out="$(printf '%s' "$json" | bash "$HOOK" 2>/dev/null)"
  if [ "$rc" -ne 0 ]; then
    got="exit=$rc"
  elif [ -n "$out" ]; then
    got="decision-output"
  elif [ -n "$err" ]; then
    got="warn"
  else
    got="quiet"
  fi
  if [ "$got" = "$expect" ]; then
    pass=$((pass+1)); results+=("✅ $label")
  else
    fail=$((fail+1)); results+=("❌ $label (expect=$expect got=$got)")
  fi
}

echo "=== warn 象限 (判定は返さない) ==="
assert "W1: > redirect"   warn "echo x > $MEM/feedback_a.md"
assert "W2: >> redirect"  warn "echo x >> $MEM/feedback_a.md"
assert "W3: tee"          warn "echo x | tee $MEM/feedback_a.md"
assert "W4: cp"           warn "cp /tmp/a.md $MEM/feedback_a.md"
assert "W5: mv"           warn "mv /tmp/a.md $MEM/feedback_a.md"

echo "=== quiet 象限 ==="
assert "Q1: cat (read)"          quiet "cat $MEM/feedback_a.md"
assert "Q2: ls (read)"           quiet "ls $MEM"
assert "Q3: 非 memory への redirect" quiet "echo x > /home/tester/notes/a.md"
assert "Q4: memory を含まない"    quiet "git status"

echo ""
echo "=== 結果 ==="
for r in "${results[@]}"; do echo "  $r"; done
echo ""
echo "pass: $pass / fail: $fail"
exit "$fail"
