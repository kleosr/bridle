#!/usr/bin/env bash
# Plan-mode regression suite. Sourced by run.sh — assumes PACK, run_test, PASS, FAIL set.

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/sessionStart_plan_mode.json" | bash "$PACK/shared/hooks/session_start.sh")"
RESULT_IS_EMPTY="$(printf '%s' "$RESULT" | jq -r 'if . == {} then "quiet" else "scaffold" end')"
run_test "session_start quiet in plan mode" "quiet" "$RESULT_IS_EMPTY"
PLAN_MODE_WRITTEN="$(cat "$PACK/state/plan-test/mode" 2>/dev/null || echo "")"
run_test "session_start writes state/mode=plan" "plan" "$PLAN_MODE_WRITTEN"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
printf 'plan\n' > "$PACK/state/mode"
RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_plan_mode.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh")"
RESULT_IS_EMPTY="$(printf '%s' "$RESULT" | jq -r 'if . == {} then "quiet" else "scaffold" end')"
run_test "before_submit_prompt quiet in plan mode" "quiet" "$RESULT_IS_EMPTY"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
printf 'plan\n' > "$PACK/state/mode"
printf '# HANDOFF — Session State\n\n## Active Objective\n\nx\n' > "$PACK/HANDOFF.md"
RESULT="$(cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/shared/hooks/stop_gate.sh" 2>/dev/null | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate accepts (no followup) in plan mode" "accept" "$RESULT"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
printf 'agent\n' > "$PACK/state/mode"
RESULT="$(cat "$PACK/tests/fixtures/stop_no_intent.json" | bash "$PACK/shared/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate still enforces in agent mode" "followup" "$RESULT"
