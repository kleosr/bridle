#!/usr/bin/env bash

RESULT="$(cat "$PACK/tests/fixtures/sessionStart_plan_mode.json" | bash "$PACK/shared/hooks/session_start.sh")"
RESULT_IS_EMPTY="$(printf '%s' "$RESULT" | jq -r 'if . == {} then "quiet" else "scaffold" end')"
run_test "session_start quiet in plan mode" "quiet" "$RESULT_IS_EMPTY"

CHAT_HAS="$(jq -n '{hook_event_name:"sessionStart",composer_mode:"chat",session_id:"chat-test",conversation_id:"chat-test"}' | bash "$PACK/shared/hooks/session_start.sh" | jq -r 'has("additional_context")')"
run_test "session_start injects NOW.md in chat mode" "true" "$CHAT_HAS"

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_plan_mode.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh")"
RESULT_CONTINUE="$(printf '%s' "$RESULT" | jq -r '.continue // empty')"
if [[ "$RESULT_CONTINUE" == "true" ]] || [[ "$(printf '%s' "$RESULT" | jq -r 'if . == {} then "quiet" else "other" end')" == "quiet" ]]; then
  echo "[pass] before_submit_prompt non-blocking in plan mode"; PASS=$((PASS + 1))
else
  echo "[fail] before_submit_prompt blocked or injected in plan mode: $RESULT"; FAIL=$((FAIL + 1))
fi
