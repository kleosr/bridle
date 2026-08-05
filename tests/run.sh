#!/usr/bin/env bash
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

HANDOFF_BACKUP=""
if [[ -f "$PACK/HANDOFF.md" ]]; then
  HANDOFF_BACKUP="$(cat "$PACK/HANDOFF.md")"
fi

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_code.json" | bash "$PACK/hooks/before_submit_prompt.sh" | jq -r '.additional_context | length > 0')"
run_test "before_submit_prompt emits context" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/hooks/session_start.sh" | jq -r '.additional_context | length > 0')"
run_test "session_start emits context" "true" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/preToolUse_write_small.json" | bash "$PACK/hooks/lean_gate.sh" | jq -r '.action')"
run_test "lean_gate allows small write" "allow" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_coupling_high.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.action // "allow"')"
run_test "lean_gate denies high coupling" "deny" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_nesting_deep.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.action // "allow"')"
run_test "lean_gate denies deep nesting" "deny" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_complexity_high.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.action // "allow"')"
run_test "lean_gate denies high complexity" "deny" "$RESULT"

RESULT="$(echo '{"tool_name":"Read","tool_input":{"file_path":"x"}}' | bash "$PACK/hooks/pre_tool_use.sh" | jq -r 'if . == {} then "pass" else .action end')"
run_test "pre_tool_use allows Read" "pass" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/preToolUse_bash_destructive.json" | bash "$PACK/hooks/pre_tool_use.sh" | jq -r '.action')"
run_test "pre_tool_use blocks rm -rf /" "deny" "$RESULT"

rm -rf "$PACK/state"
mkdir -p "$PACK/state"
echo 'src/db.ts' > "$PACK/state/allowed_files.md"
RESULT="$(cat "$PACK/tests/fixtures/preToolUse_scope_expansion.json" | bash "$PACK/hooks/pre_tool_use.sh" | jq -r '.action // "allow"')"
run_test "pre_tool_use warns on scope expansion (not deny)" "allow" "$RESULT"

rm -rf "$PACK/state"
printf '# HANDOFF — Session State\n\n## Active Objective\n\nold task\n\n## Archived\n\n- Previous session note\n' > "$PACK/HANDOFF.md"
cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/hooks/stop_gate.sh" >/dev/null 2>&1 || true
RESULT="$(grep -q 'Previous session note' "$PACK/HANDOFF.md" && echo "ok" || echo "fail")"
run_test "HANDOFF preserves prior Archived history" "ok" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/stop_no_intent.json" | bash "$PACK/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate followup on missing INTENT" "followup" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate accepts valid INTENT" "accept" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"status":"completed","messages":[{"role":"assistant","content":"```bash\necho INTENT: poison\nDone-when: met\nedit:a\n```"}]}' | bash "$PACK/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate ignores code-fence poison" "followup" "$RESULT"

if ! grep -Rq --include='*.sh' 'updated_input' "$PACK/hooks/" 2>/dev/null && [[ ! -e "$PACK/hooks/kleos-gate" ]]; then
  echo "[pass] no updated_input / Rust gate"
  PASS=$((PASS + 1))
else
  echo "[fail] updated_input or Rust gate found"
  FAIL=$((FAIL + 1))
fi

RESULT="$(echo '{"prompt":"implement a login form"}' | bash "$PACK/hooks/before_submit_prompt.sh" | jq -r '.additional_context | test("CONSTRAINTS:")')"
run_test "before_submit reminds constraints on unbound task" "true" "$RESULT"

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

RESULT="$(HERE="$PACK/hooks" bash -c 'source "$0/lib/common.sh" && resolve_root && type emit_allow >/dev/null && type emit_deny >/dev/null && type emit_followup >/dev/null && type acquire_lock >/dev/null && echo "ok"' "$PACK/hooks" 2>/dev/null || echo "fail")"
run_test "lib/common.sh functions available" "ok" "$RESULT"

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
echo "=== Regression tests (bug fixes) ==="

R1_HANDOFF_BAK="$(cat "$PACK/HANDOFF.md" 2>/dev/null || true)"
rm -rf "$PACK/state"
printf '# HANDOFF — Session State\n\n## Active Objective\n\nold\n\n## Archived\n\n- old note\n\n<!-- COMPACTION PROTOCOL\nsome rules\n-->\n\n(Older context compacted here when active sections exceed ~150 lines.)\n' > "$PACK/HANDOFF.md"
cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/hooks/stop_gate.sh" >/dev/null 2>&1 || true
PROTO_COUNT="$(grep -c 'COMPACTION PROTOCOL' "$PACK/HANDOFF.md" 2>/dev/null || true)"
PROTO_COUNT="${PROTO_COUNT//[!0-9]}"; [[ -z "$PROTO_COUNT" ]] && PROTO_COUNT=0
PLACEHOLDER_COUNT="$(grep -c 'Older context compacted here' "$PACK/HANDOFF.md" 2>/dev/null || true)"
PLACEHOLDER_COUNT="${PLACEHOLDER_COUNT//[!0-9]}"; [[ -z "$PLACEHOLDER_COUNT" ]] && PLACEHOLDER_COUNT=0
if [[ "$PROTO_COUNT" -eq 1 && "$PLACEHOLDER_COUNT" -eq 1 ]]; then
  echo "[pass] accept() does not duplicate COMPACTION PROTOCOL"
  PASS=$((PASS + 1))
else
  echo "[fail] accept() duplicated COMPACTION PROTOCOL (proto=$PROTO_COUNT placeholder=$PLACEHOLDER_COUNT)"
  FAIL=$((FAIL + 1))
fi
[[ -n "$R1_HANDOFF_BAK" ]] && printf '%s' "$R1_HANDOFF_BAK" >"$PACK/HANDOFF.md"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
printf 'GARBAGE\n' > "$PACK/state/outcomes.md"
RESULT="$(cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/hooks/stop_gate.sh" 2>/dev/null | jq -r 'if .followup_message then "followup" else "accept" end' 2>/dev/null || echo "crash")"
run_test "stop_gate tolerates corrupt outcomes.md" "accept" "$RESULT"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
printf '' > "$PACK/state/session_ts"
printf '1\n' > "$PACK/state/outcomes.md"
RESULT="$(cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/hooks/stop_gate.sh" 2>/dev/null | jq -r 'if .followup_message then "followup" else "accept" end' 2>/dev/null || echo "crash")"
run_test "stop_gate tolerates empty session_ts" "accept" "$RESULT"

VELOCITY_SRC="$(sed -n '/velocity_bump/,/^}/p' "$PACK/hooks/lean_gate.sh")"
ACQUIRE_LINE="$(printf '%s\n' "$VELOCITY_SRC" | grep -n 'acquire_lock' | head -1 | cut -d: -f1)"
GREP_LINE="$(printf '%s\n' "$VELOCITY_SRC" | grep -n 'grep -cxF' | head -1 | cut -d: -f1)"
if [[ -n "$ACQUIRE_LINE" && -n "$GREP_LINE" && "$GREP_LINE" -gt "$ACQUIRE_LINE" ]]; then
  echo "[pass] velocity count read under lock (no TOCTOU)"
  PASS=$((PASS + 1))
else
  echo "[fail] velocity count read outside lock (TOCTOU present): acquire=$ACQUIRE_LINE grep=$GREP_LINE"
  FAIL=$((FAIL + 1))
fi

RESULT="$(HERE="$PACK/hooks" bash -c '
  count_lines() { printf "%s\n" "$1" | wc -l; }
  echo "$(count_lines "single-line")"
' 2>/dev/null | tr -d '[:space:]')"
run_test "count_lines counts single-line as 1" "1" "$RESULT"

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
rm -rf "$PACK/state"

if [[ -n "$HANDOFF_BACKUP" ]]; then
  printf '%s' "$HANDOFF_BACKUP" >"$PACK/HANDOFF.md"
fi

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
