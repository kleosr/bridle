#!/usr/bin/env bash

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_code.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit_prompt emits continue:true" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | length > 0')"
run_test "session_start emits additional_context" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("HANDOFF")')"
run_test "session_start injects HANDOFF tail" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("DEBERES:")')"
run_test "session_start does not inject DEBERES duty" "false" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("JOB CARD") and test("INTENT:") and test("OBJECTIVE=")')"
run_test "session_start does not inject JOB CARD template" "false" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("PONYTAIL LADDER")')"
run_test "session_start does not dump ponytail ladder (law stays in mdc)" "false" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"please fix src/auth.ts login bug"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if .continue==true and ((.user_message // "")|test("FILE_MAP nudge")) then "nudge" else "no" end')"
run_test "before_submit does not FILE_MAP-nudge (continue:true)" "no" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"implement a login form"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if .continue==true and ((.user_message // "")|test("JOB CARD")) then "job" else "other" end')"
run_test "before_submit does not JOB CARD nudge" "other" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_secret.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit blocks secret/token patterns" "false" "$RESULT"

if jq -e '.hooks.sessionStart and .hooks.beforeSubmitPrompt and .hooks.beforeShellExecution and .hooks.beforeReadFile' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks|keys|length == 4' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks.sessionStart[0].command == "./hooks/session_start.sh"' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '(.hooks|has("preToolUse")|not) and (.hooks|has("stop")|not)' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks|has("sessionStart")|not' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null \
  && jq -e '.hooks.beforeShellExecution and .hooks.beforeReadFile and .hooks.beforeSubmitPrompt' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null \
  && jq -e '.hooks|keys|length == 3' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null; then
  echo "[pass] hooks.json is 4 native events; cloud is 3 (no sessionStart)"; PASS=$((PASS + 1))
else
  echo "[fail] hooks.json / hooks.cloud.json registration wrong"; FAIL=$((FAIL + 1))
fi

if jq -e '(.hooks|has("beforeTabFileRead")|not) and (.hooks|has("beforeMCPExecution")|not)' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks|has("sessionStart")|not' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null; then
  echo "[pass] hooks.json omits tab+mcp; hooks.cloud.json omits sessionStart"; PASS=$((PASS + 1))
else
  echo "[fail] cloud/tab/mcp hooks.json shape wrong"; FAIL=$((FAIL + 1))
fi
