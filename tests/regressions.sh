#!/usr/bin/env bash
# Sourced by run.sh. Regression tests for past bug fixes (HANDOFF archive, compaction, TOCTOU, etc.

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

LONG_HANDOFF="$(mktemp)"
for i in $(seq 1 200); do echo "line $i"; done > "$LONG_HANDOFF"
RESULT="$(HERE="$PACK/hooks" bash -c '
  source "$0/lib/common.sh"; resolve_root
  HANDOFF="'"$LONG_HANDOFF"'"
  HL="$(wc -l < "$HANDOFF" 2>/dev/null || echo 0)"
  if [[ "$HL" -gt 180 ]]; then echo "compact"; else echo "skip"; fi
' "$PACK/hooks" 2>/dev/null || echo "error")"
rm -f "$LONG_HANDOFF"
run_test "HANDOFF compaction gate fires >180 lines" "compact" "$RESULT"

R1_HANDOFF_BAK="$(cat "$PACK/HANDOFF.md" 2>/dev/null || true)"
rm -rf "$PACK/state"
printf '# HANDOFF — Session State\n\n## Active Objective\n\nold\n\n## Archived\n\n- old note\n\n<!-- COMPACTION PROTOCOL\nsome rules\n-->\n\n(Older context compacted here when active sections exceed ~150 lines.)\n' > "$PACK/HANDOFF.md"
cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/hooks/stop_gate.sh" >/dev/null 2>&1 || true
PROTO_COUNT="$(grep -c 'COMPACTION PROTOCOL' "$PACK/HANDOFF.md" 2>/dev/null || true)"
PROTO_COUNT="${PROTO_COUNT//[!0-9]}"; [[ -z "$PROTO_COUNT" ]] && PROTO_COUNT=0
PLACEHOLDER_COUNT="$(grep -c 'Older context compacted here' "$PACK/HANDOFF.md" 2>/dev/null || true)"
PLACEHOLDER_COUNT="${PLACEHOLDER_COUNT//[!0-9]}"; [[ -z "$PLACEHOLDER_COUNT" ]] && PLACEHOLDER_COUNT=0
if [[ "$PROTO_COUNT" -eq 1 && "$PLACEHOLDER_COUNT" -eq 1 ]]; then
  echo "[pass] accept() does not duplicate COMPACTION PROTOCOL"; PASS=$((PASS + 1))
else
  echo "[fail] accept() duplicated COMPACTION PROTOCOL (proto=$PROTO_COUNT placeholder=$PLACEHOLDER_COUNT)"; FAIL=$((FAIL + 1))
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
  echo "[pass] velocity count read under lock (no TOCTOU)"; PASS=$((PASS + 1))
else
  echo "[fail] velocity count read outside lock (TOCTOU present): acquire=$ACQUIRE_LINE grep=$GREP_LINE"; FAIL=$((FAIL + 1))
fi

RESULT="$(HERE="$PACK/hooks" bash -c '
  count_lines() { printf "%s\n" "$1" | wc -l; }
  echo "$(count_lines "single-line")"
' 2>/dev/null | tr -d '[:space:]')"
run_test "count_lines counts single-line as 1" "1" "$RESULT"
