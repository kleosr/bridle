#!/usr/bin/env bash

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/sessionStart_plan_mode.json" | bash "$PACK/shared/hooks/session_start.sh")"
RESULT_IS_EMPTY="$(printf '%s' "$RESULT" | jq -r 'if . == {} then "quiet" else "scaffold" end')"
run_test "session_start quiet in plan mode" "quiet" "$RESULT_IS_EMPTY"
PLAN_MODE_WRITTEN="$(cat "$PACK/state/plan-test/mode" 2>/dev/null || echo "")"
run_test "session_start writes state/mode=plan" "plan" "$PLAN_MODE_WRITTEN"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
printf 'plan\n' > "$PACK/state/mode"
RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_plan_mode.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh")"
RESULT_CONTINUE="$(printf '%s' "$RESULT" | jq -r '.continue // empty')"
if [[ "$RESULT_CONTINUE" == "true" ]] || [[ "$(printf '%s' "$RESULT" | jq -r 'if . == {} then "quiet" else "other" end')" == "quiet" ]]; then
  echo "[pass] before_submit_prompt non-blocking in plan mode"; PASS=$((PASS + 1))
else
  echo "[fail] before_submit_prompt blocked or injected in plan mode: $RESULT"; FAIL=$((FAIL + 1))
fi
