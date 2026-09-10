#!/usr/bin/env bash

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_code.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit_prompt emits continue:true" "true" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"please fix src/auth.ts login bug"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if .continue==true and ((.user_message // "")|test("FILE_MAP nudge")) then "nudge" else "no" end')"
run_test "before_submit does not FILE_MAP-nudge (continue:true)" "no" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"implement a login form"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if .continue==true and ((.user_message // "")|test("JOB CARD")) then "job" else "other" end')"
run_test "before_submit does not JOB CARD nudge" "other" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_secret.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit blocks secret/token patterns" "false" "$RESULT"

if jq -e '.hooks.beforeSubmitPrompt and .hooks.beforeShellExecution and .hooks.beforeReadFile and .hooks.stop' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks.beforeSubmitPrompt[0].failClosed == true and .hooks.beforeShellExecution[0].failClosed == true and .hooks.beforeReadFile[0].failClosed == true' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks.stop[0].command == "./hooks/stop.sh" and .hooks.stop[0].loop_limit == 1' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks.beforeShellExecution and .hooks.beforeReadFile and .hooks.beforeSubmitPrompt' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null \
  && jq -e '.hooks.beforeSubmitPrompt[0].failClosed == true and .hooks.beforeShellExecution[0].failClosed == true' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null; then
  echo "[pass] hooks.json registers submit+shell+read+stop with contracts; cloud registers submit+shell+read"; PASS=$((PASS + 1))
else
  echo "[fail] hooks.json / hooks.cloud.json registration wrong"; FAIL=$((FAIL + 1))
fi

if jq -e '(.hooks|has("sessionStart")|not) and (.hooks|has("beforeTabFileRead")|not) and (.hooks|has("beforeMCPExecution")|not)' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '(.hooks|has("preToolUse")|not) and (.hooks|has("postToolUse")|not)' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '(.hooks|has("sessionStart")|not) and (.hooks|has("stop")|not)' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null; then
  echo "[pass] hooks.json omits sessionStart/tab/mcp/pre/post; cloud omits sessionStart/stop"; PASS=$((PASS + 1))
else
  echo "[fail] cloud/tab/mcp/session hooks.json shape wrong"; FAIL=$((FAIL + 1))
fi

LAW_STALE=no
for f in "$PACK/shared/rules/agent.mdc" "$PACK/shared/rules/ponytail.mdc" \
  "$PACK/shared/rules/vibe.mdc" "$PACK/shared/rules/postgres.mdc" \
  "$PACK/shared/rules/supabase.mdc" \
  "$PACK/shared/rules/next.mdc" "$PACK/shared/rules/vite.mdc" \
  "$PACK/shared/rules/astro.mdc" "$PACK/shared/rules/complexity.mdc" \
  "$PACK/shared/rules/pnpm.mdc" "$PACK/shared/rules/testing.mdc" \
  "$PACK/shared/rules/types.mdc" "$PACK/shared/rules/USER-RULES.paste.txt" \
  "$PACK/shared/skills/ponytail/SKILL.md" \
  "$PACK/shared/skills/testing/SKILL.md" \
  "$PACK/shared/skills/complexity/SKILL.md"; do
  [[ -f "$f" ]] || { LAW_STALE=yes; continue; }
  if grep -qE 'stop_gate|lean_gate|post_tool_use|pre_tool_use|before_mcp' "$f"; then
    LAW_STALE=yes
  fi
done
run_test "law and skills do not name deleted hooks" "no" "$LAW_STALE"
