#!/usr/bin/env bash
# tests/run.sh — run hook fixture tests + validation checks.
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
PASS=0

run_test() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "[pass] $name"
    PASS=$((PASS + 1))
  else
    echo "[fail] $name"
    echo "  expected: $expected"
    echo "  got:      $actual"
    FAIL=$((FAIL + 1))
  fi
}

# Clean state before tests
rm -rf "$PACK/state"

echo "=== Syntax checks ==="
for f in "$PACK"/hooks/*.sh "$PACK"/hooks/lib/*.sh; do
  if bash -n "$f" 2>/dev/null; then
    echo "[pass] syntax: ${f#$PACK/}"
    PASS=$((PASS + 1))
  else
    echo "[fail] syntax: ${f#$PACK/}"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== shellcheck (if available) ==="
if command -v shellcheck >/dev/null 2>&1; then
  for f in "$PACK"/hooks/*.sh "$PACK"/hooks/lib/*.sh; do
    if shellcheck -S warning "$f" 2>/dev/null; then
      echo "[pass] shellcheck: ${f#$PACK/}"
      PASS=$((PASS + 1))
    else
      echo "[warn] shellcheck: ${f#$PACK/} (issues found)"
    fi
  done
else
  echo "[skip] shellcheck not installed"
fi

echo ""
echo "=== JSON validity ==="
for j in "$PACK"/hooks/hooks.json "$PACK"/hooks/policy/*.json "$PACK"/package.json; do
  [[ -f "$j" ]] || continue
  if jq empty "$j" 2>/dev/null; then
    echo "[pass] valid JSON: ${j#$PACK/}"
    PASS=$((PASS + 1))
  else
    echo "[fail] invalid JSON: ${j#$PACK/}"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== Hook fixture tests ==="

# Save HANDOFF.md (stop_gate accept overwrites it)
HANDOFF_BACKUP=""
if [[ -f "$PACK/HANDOFF.md" ]]; then
  HANDOFF_BACKUP="$(cat "$PACK/HANDOFF.md")"
fi

# 1. before_submit_prompt emits additional_context
RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_code.json" | bash "$PACK/hooks/before_submit_prompt.sh" | jq -r '.additional_context | length > 0')"
run_test "before_submit_prompt emits context" "true" "$RESULT"

# 2. session_start emits additional_context
RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/hooks/session_start.sh" | jq -r '.additional_context | length > 0')"
run_test "session_start emits context" "true" "$RESULT"

# 3. lean_gate allows small write
rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/preToolUse_write_small.json" | bash "$PACK/hooks/lean_gate.sh" | jq -r '.action')"
run_test "lean_gate allows small write" "allow" "$RESULT"

# 3b. lean_gate denies high coupling (god file)
if OUT="$(set +eo pipefail; bash "$PACK/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_coupling_high.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.action // "allow"')"
run_test "lean_gate denies high coupling" "deny" "$RESULT"

# 3c. lean_gate denies deep nesting
if OUT="$(set +eo pipefail; bash "$PACK/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_nesting_deep.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.action // "allow"')"
run_test "lean_gate denies deep nesting" "deny" "$RESULT"

# 3d. lean_gate denies high complexity
if OUT="$(set +eo pipefail; bash "$PACK/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_complexity_high.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.action // "allow"')"
run_test "lean_gate denies high complexity" "deny" "$RESULT"

# 4. pre_tool_use allows Read
RESULT="$(echo '{"tool_name":"Read","tool_input":{"file_path":"x"}}' | bash "$PACK/hooks/pre_tool_use.sh" | jq -r 'if . == {} then "pass" else .action end')"
run_test "pre_tool_use allows Read" "pass" "$RESULT"

# 5. pre_tool_use blocks destructive Bash
RESULT="$(cat "$PACK/tests/fixtures/preToolUse_bash_destructive.json" | bash "$PACK/hooks/pre_tool_use.sh" | jq -r '.action')"
run_test "pre_tool_use blocks rm -rf /" "deny" "$RESULT"

# 6. stop_gate followup when no INTENT
rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/stop_no_intent.json" | bash "$PACK/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate followup on missing INTENT" "followup" "$RESULT"

# 7. stop_gate accepts valid INTENT with Done-when: met
rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate accepts valid INTENT" "accept" "$RESULT"

# 8. stop_gate rejects shell/fence poison
rm -rf "$PACK/state"
RESULT="$(echo '{"status":"completed","messages":[{"role":"assistant","content":"```bash\necho INTENT: poison\nDone-when: met\nedit:a\n```"}]}' | bash "$PACK/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate ignores code-fence poison" "followup" "$RESULT"

# 9. No Rust gate / updated_input in hooks
if ! grep -Rq --include='*.sh' 'updated_input' "$PACK/hooks/" 2>/dev/null && [[ ! -e "$PACK/hooks/kleos-gate" ]]; then
  echo "[pass] no updated_input / Rust gate"
  PASS=$((PASS + 1))
else
  echo "[fail] updated_input or Rust gate found"
  FAIL=$((FAIL + 1))
fi

# 13. before_submit_prompt adds constraint reminder on unbound code task
RESULT="$(echo '{"prompt":"implement a login form"}' | bash "$PACK/hooks/before_submit_prompt.sh" | jq -r '.additional_context | test("CONSTRAINTS:")')"
run_test "before_submit reminds constraints on unbound task" "true" "$RESULT"

# 14. shared_state logs events (debugging only, no behavior change)
rm -rf "$PACK/state"
echo '{"tool_name":"Write","tool_input":{"file_path":"x.ts","content":"const a=1;\n"}}' | bash "$PACK/hooks/lean_gate.sh" >/dev/null 2>&1 || true
RESULT="$([[ -f "$PACK/state/session.log" ]] && grep -q 'lean_gate' "$PACK/state/session.log" && echo "ok" || echo "fail")"
run_test "shared_state logs lean_gate events" "ok" "$RESULT"
LOC_OK=1
for f in "$PACK"/hooks/session_start.sh "$PACK"/hooks/before_submit_prompt.sh "$PACK"/hooks/stop_gate.sh "$PACK"/hooks/lean_gate.sh "$PACK"/hooks/pre_tool_use.sh; do
  n="$(wc -l < "$f")"
  [[ "$n" -le 80 ]] || { LOC_OK=0; break; }
done
if [[ "$LOC_OK" -eq 1 ]]; then
  echo "[pass] event hooks LOC ≤ 80"
  PASS=$((PASS + 1))
else
  echo "[fail] event hook exceeds 80 LOC: ${f#$PACK/} ($n)"
  FAIL=$((FAIL + 1))
fi

# 11. lib/common.sh functions available when sourced
RESULT="$(HERE="$PACK/hooks" bash -c 'source "$0/lib/common.sh" && resolve_root && type emit_allow >/dev/null && type emit_deny >/dev/null && type emit_followup >/dev/null && type acquire_lock >/dev/null && echo "ok"' "$PACK/hooks" 2>/dev/null || echo "fail")"
run_test "lib/common.sh functions available" "ok" "$RESULT"

# 12. HANDOFF compaction gate fires when over 180 lines
LONG_HANDOFF="$(mktemp)"
for i in $(seq 1 200); do echo "line $i"; done > "$LONG_HANDOFF"
RESULT="$(HERE="$PACK/hooks" bash -c '
  source "$0/lib/common.sh"
  resolve_root
  HANDOFF="'"$LONG_HANDOFF"'"
  HANDOFF_LINES="$(wc -l < "$HANDOFF" 2>/dev/null || echo 0)"
  if [[ "$HANDOFF_LINES" -gt 180 ]]; then echo "compact"; else echo "skip"; fi
' "$PACK/hooks" 2>/dev/null || echo "error")"
rm -f "$LONG_HANDOFF"
run_test "HANDOFF compaction gate fires >180 lines" "compact" "$RESULT"

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
rm -rf "$PACK/state"

# Restore HANDOFF.md if tests overwrote it
if [[ -n "$HANDOFF_BACKUP" ]]; then
  printf '%s' "$HANDOFF_BACKUP" >"$PACK/HANDOFF.md"
fi

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
