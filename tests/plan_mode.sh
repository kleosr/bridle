#!/usr/bin/env bash
# before_submit stays non-blocking in plan mode (no inject, no block).

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_plan_mode.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh")"
RESULT_CONTINUE="$(printf '%s' "$RESULT" | jq -r '.continue // empty')"
if [[ "$RESULT_CONTINUE" == "true" ]] || [[ "$(printf '%s' "$RESULT" | jq -r 'if . == {} then "quiet" else "other" end')" == "quiet" ]]; then
  echo "[pass] before_submit_prompt non-blocking in plan mode"; PASS=$((PASS + 1))
else
  echo "[fail] before_submit_prompt blocked or injected in plan mode: $RESULT"; FAIL=$((FAIL + 1))
fi
