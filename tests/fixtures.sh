#!/usr/bin/env bash

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_code.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit_prompt emits continue:true" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | length > 0')"
run_test "session_start emits additional_context" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("NOW")')"
run_test "session_start injects NOW" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("DEBERES:")')"
run_test "session_start does not inject DEBERES duty" "false" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("JOB CARD") and test("INTENT:") and test("OBJECTIVE=")')"
run_test "session_start does not inject JOB CARD template" "false" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("PONYTAIL LADDER")')"
run_test "session_start does not dump ponytail ladder (law stays in mdc)" "false" "$RESULT"

FAKE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-home.XXXXXX")"
FAKE_C="$FAKE_HOME/.cursor"
WS="$(mktemp -d "${TMPDIR:-/tmp}/kleos-ws.XXXXXX")"
mkdir -p "$FAKE_C/hooks/lib"
cp "$PACK/shared/hooks/session_start.sh" "$FAKE_C/hooks/"
cp "$PACK/shared/hooks/lib/common.sh" "$FAKE_C/hooks/lib/"
MARKER="WORKSPACE_ROOT_NOW_PROBE_8f3a"
printf '# NOW\n\n%s\n' "$MARKER" >"$WS/NOW.md"
PAYLOAD="$(jq -n --arg wr "$WS" '{hook_event_name:"sessionStart",composer_mode:"agent",workspace_roots:[$wr]}')"
RESULT="$(cd "$FAKE_C" && printf '%s\n' "$PAYLOAD" | HOME="$FAKE_HOME" bash "$FAKE_C/hooks/session_start.sh" | jq -r --arg m "$MARKER" '.additional_context | test($m)')"
run_test "session_start uses workspace_roots[0] when cwd is not the pack" "true" "$RESULT"
rm -rf "$FAKE_HOME" "$WS"

FAKE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-home.XXXXXX")"
FAKE_C="$FAKE_HOME/.cursor"
WS="$(mktemp -d "${TMPDIR:-/tmp}/kleos-ws.XXXXXX")"
mkdir -p "$FAKE_C/hooks/lib"
cp "$PACK/shared/hooks/session_start.sh" "$FAKE_C/hooks/"
cp "$PACK/shared/hooks/lib/common.sh" "$FAKE_C/hooks/lib/"
{
  printf '# NOW\n\n## Now\n\nKEEP_ME_NOW\n\n## Archived\n\n'
  i=1
  while [[ "$i" -le 30 ]]; do
    printf 'archive line %s\n' "$i"
    i=$((i + 1))
  done
} >"$WS/NOW.md"
PAYLOAD="$(jq -n --arg wr "$WS" '{hook_event_name:"sessionStart",composer_mode:"agent",workspace_roots:[$wr]}')"
RESULT="$(cd "$FAKE_C" && printf '%s\n' "$PAYLOAD" | HOME="$FAKE_HOME" bash "$FAKE_C/hooks/session_start.sh" | jq -r '.additional_context | test("KEEP_ME_NOW")')"
RESULT_ARCH="$(cd "$FAKE_C" && printf '%s\n' "$PAYLOAD" | HOME="$FAKE_HOME" bash "$FAKE_C/hooks/session_start.sh" | jq -r '.additional_context | test("archive line 30")')"
run_test "session_start injects Now section from the top" "true" "$RESULT"
run_test "session_start does not inject Archived filler" "false" "$RESULT_ARCH"
rm -rf "$FAKE_HOME" "$WS"

FAKE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-home.XXXXXX")"
FAKE_C="$FAKE_HOME/.cursor"
WS="$(mktemp -d "${TMPDIR:-/tmp}/kleos-ws.XXXXXX")"
mkdir -p "$FAKE_C/hooks/lib"
cp "$PACK/shared/hooks/session_start.sh" "$FAKE_C/hooks/"
cp "$PACK/shared/hooks/lib/common.sh" "$FAKE_C/hooks/lib/"
{
  printf '# Handoff\n\n**Goal:** LIVE_JOB_AT_TOP\n\n## Done\n\n- done item\n\n'
  printf '## Open\n\n- open item\n\n## Blockers\n\n- none\n\n'
  printf '## Next\n\nNEXT_ONLY_SECTION\n\n## Verify\n\nVERIFY_MARKER\n\n'
  printf '## Notes\n\n- notes\n'
} >"$WS/NOW.md"
PAYLOAD="$(jq -n --arg wr "$WS" '{hook_event_name:"sessionStart",composer_mode:"agent",workspace_roots:[$wr]}')"
RESULT="$(cd "$FAKE_C" && printf '%s\n' "$PAYLOAD" | HOME="$FAKE_HOME" bash "$FAKE_C/hooks/session_start.sh" | jq -r '.additional_context | test("VERIFY_MARKER")')"
run_test "session_start falls back when NOW.md only shares Next" "true" "$RESULT"
rm -rf "$FAKE_HOME" "$WS"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"please fix src/auth.ts login bug"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if .continue==true and ((.user_message // "")|test("FILE_MAP nudge")) then "nudge" else "no" end')"
run_test "before_submit does not FILE_MAP-nudge (continue:true)" "no" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"implement a login form"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if .continue==true and ((.user_message // "")|test("JOB CARD")) then "job" else "other" end')"
run_test "before_submit does not JOB CARD nudge" "other" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_secret.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit blocks secret/token patterns" "false" "$RESULT"

if jq -e '.hooks.sessionStart and .hooks.beforeSubmitPrompt and .hooks.beforeShellExecution and .hooks.beforeReadFile and .hooks.stop' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks|keys|length == 5' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks.sessionStart[0].command == "./hooks/session_start.sh"' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks.stop[0].command == "./hooks/stop.sh"' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '(.hooks|has("preToolUse")|not) and (.hooks|has("postToolUse")|not)' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks|has("sessionStart")|not' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null \
  && jq -e '.hooks.beforeShellExecution and .hooks.beforeReadFile and .hooks.beforeSubmitPrompt' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null \
  && jq -e '.hooks|keys|length == 3' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null; then
  echo "[pass] hooks.json is 5 native events; cloud is 3 (no sessionStart, no stop)"; PASS=$((PASS + 1))
else
  echo "[fail] hooks.json / hooks.cloud.json registration wrong"; FAIL=$((FAIL + 1))
fi

if jq -e '(.hooks|has("beforeTabFileRead")|not) and (.hooks|has("beforeMCPExecution")|not)' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks|has("sessionStart")|not' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null; then
  echo "[pass] hooks.json omits tab+mcp; hooks.cloud.json omits sessionStart"; PASS=$((PASS + 1))
else
  echo "[fail] cloud/tab/mcp hooks.json shape wrong"; FAIL=$((FAIL + 1))
fi

LAW_STALE=no
for f in "$PACK/shared/rules/agent.mdc" "$PACK/shared/rules/ponytail.mdc" \
  "$PACK/shared/rules/vibe.mdc" "$PACK/shared/rules/postgres.mdc" \
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
