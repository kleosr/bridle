#!/usr/bin/env bash
# Sourced by run.sh. Hook fixture tests (agent-mode behavior).

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_code.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit_prompt emits continue:true" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | length > 0')"
run_test "session_start emits additional_context" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("DEBERES:")')"
run_test "session_start injects DEBERES duty" "true" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/preToolUse_write_small.json" | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r '.permission')"
run_test "lean_gate allows small write" "allow" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/shared/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_coupling_high.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.permission // "allow"')"
run_test "lean_gate denies high coupling" "deny" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/shared/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_nesting_deep.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.permission // "allow"')"
run_test "lean_gate denies deep nesting" "deny" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/shared/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_complexity_high.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.permission // "allow"')"
run_test "lean_gate denies high complexity" "deny" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/shared/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_comments_high.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.permission // "allow"')"
run_test "lean_gate denies high comment ratio on executable source" "deny" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"tool_name":"Write","tool_input":{"file_path":"docs/guide.md","content":"# Title\n\nThis is a long prose doc.\n\nMore prose here.\n"}}' | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r '.permission // "allow"')"
run_test "lean_gate skips comment gate on markdown docs" "allow" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"tool_name":"Write","tool_input":{"file_path":"src/clean.ts","content":"export const authenticate = (token: string) => Boolean(token);\nexport const refresh = (token: string) => token;\n"}}' | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r '.permission // "allow"')"
run_test "lean_gate allows self-documenting source (low comment ratio)" "allow" "$RESULT"

RESULT="$(echo '{"tool_name":"Read","tool_input":{"file_path":"x"}}' | bash "$PACK/shared/hooks/pre_tool_use.sh" | jq -r 'if . == {} then "pass" else .permission end')"
run_test "pre_tool_use allows Read" "pass" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/preToolUse_bash_destructive.json" | bash "$PACK/shared/hooks/pre_tool_use.sh" | jq -r '.permission')"
run_test "pre_tool_use blocks destructive Bash alias" "deny" "$RESULT"

RESULT="$(echo '{"tool_name":"Shell","tool_input":{"command":"rm -rf /"}}' | bash "$PACK/shared/hooks/pre_tool_use.sh" | jq -r '.permission // "none"')"
run_test "pre_tool_use blocks destructive Shell (Cursor primary)" "deny" "$RESULT"

RESULT="$(echo '{"tool_name":"Bash","hook_event_name":"preToolUse","tool_input":{"command":"rm -rf /"}}' | bash "$PACK/shared/hooks/pre_tool_use.sh" | jq -r '.permission // "none"')"
run_test "pre_tool_use Cursor-only deny even with hook_event_name" "deny" "$RESULT"

RESULT="$(echo '{"command":"rm -rf /","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution blocks destructive command" "deny" "$RESULT"

RESULT="$(echo '{"command":"ls -la","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution allows safe command" "allow" "$RESULT"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
echo 'src/db.ts' > "$PACK/state/allowed_files.md"
RESULT="$(cat "$PACK/tests/fixtures/preToolUse_scope_expansion.json" | bash "$PACK/shared/hooks/pre_tool_use.sh" | jq -r '.permission // "allow"')"
run_test "pre_tool_use scope expansion uses allow permission" "allow" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"implement a login form"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit continues unbound task (no context inject)" "true" "$RESULT"
RESULT="$([[ -f "$PACK/state/route" ]] && cat "$PACK/state/route" || echo missing)"
run_test "before_submit still writes route=code for unbound task" "code" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_code_ponytail.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit continue:true on code route" "true" "$RESULT"
RESULT="$([[ -f "$PACK/state/outcomes.md" ]] && echo ok || echo missing)"
run_test "before_submit still writes outcomes.md" "ok" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"the form breaks on submit"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit continues bugfix prompt" "true" "$RESULT"
RESULT="$(cat "$PACK/state/route" 2>/dev/null || echo missing)"
run_test "before_submit routes bugfix to code" "code" "$RESULT"

rm -rf "$PACK/state"
echo '{"tool_name":"Write","tool_input":{"file_path":"x.ts","content":"const a=1;\n"}}' | bash "$PACK/shared/hooks/lean_gate.sh" >/dev/null 2>&1 || true
RESULT="$([[ -f "$PACK/state/session.log" ]] && grep -q 'lean_gate' "$PACK/state/session.log" && echo "ok" || echo "fail")"
run_test "shared_state logs lean_gate events" "ok" "$RESULT"

if ! grep -Rq --include='*.sh' 'updated_input' "$PACK/shared/hooks/" 2>/dev/null && [[ ! -e "$PACK/shared/hooks/kleos-gate" ]]; then
  echo "[pass] no updated_input / Rust gate"; PASS=$((PASS + 1))
else
  echo "[fail] updated_input or Rust gate found"; FAIL=$((FAIL + 1))
fi

# Emitters must not use Claude/legacy Cursor shapes
if ! grep -RE --include='*.sh' '\{action:|"action":|additionalContext' "$PACK/shared/hooks/" 2>/dev/null | grep -v 'AGENTS.md' >/dev/null; then
  echo "[pass] no legacy action/additionalContext emitters"; PASS=$((PASS + 1))
else
  echo "[fail] legacy action/additionalContext still present:"; FAIL=$((FAIL + 1))
  grep -RE --include='*.sh' '\{action:|"action":|additionalContext' "$PACK/shared/hooks/" 2>/dev/null || true
fi

if grep -q '"timeout"' "$PACK/shared/hooks/hooks.json" && ! grep -q 'timeoutSec' "$PACK/shared/hooks/hooks.json"; then
  echo "[pass] hooks.json uses timeout (not timeoutSec)"; PASS=$((PASS + 1))
else
  echo "[fail] hooks.json timeout field wrong"; FAIL=$((FAIL + 1))
fi

if grep -q 'beforeShellExecution' "$PACK/shared/hooks/hooks.json" && grep -q 'Shell' "$PACK/shared/hooks/hooks.json"; then
  echo "[pass] hooks.json wires beforeShellExecution + Shell matcher"; PASS=$((PASS + 1))
else
  echo "[fail] hooks.json missing Shell/beforeShellExecution"; FAIL=$((FAIL + 1))
fi

LOC_OK=1
for f in "$PACK"/shared/hooks/session_start.sh "$PACK"/shared/hooks/session_end.sh "$PACK"/shared/hooks/before_submit_prompt.sh "$PACK"/shared/hooks/stop_gate.sh "$PACK"/shared/hooks/lean_gate.sh "$PACK"/shared/hooks/pre_tool_use.sh "$PACK"/shared/hooks/before_shell.sh "$PACK"/shared/hooks/subagent_start.sh "$PACK"/shared/hooks/subagent_stop.sh "$PACK"/shared/hooks/after_shell.sh "$PACK"/shared/hooks/before_read_file.sh; do
  n="$(wc -l < "$f")"
  [[ "$n" -le 80 ]] || { LOC_OK=0; break; }
done
if [[ "$LOC_OK" -eq 1 ]]; then
  echo "[pass] event hooks LOC ≤ 80"; PASS=$((PASS + 1))
else
  echo "[fail] event hook exceeds 80 LOC: ${f#$PACK/} ($n)"; FAIL=$((FAIL + 1))
fi

RESULT="$(HERE="$PACK/shared/hooks" bash -c 'source "$0/lib/common.sh" && resolve_root && type emit_allow >/dev/null && type emit_deny >/dev/null && type emit_followup >/dev/null && type emit_continue >/dev/null && type emit_context >/dev/null && type acquire_lock >/dev/null && type is_agent_mode >/dev/null && type extract_conv_id >/dev/null && type state_dir >/dev/null && echo "ok"' "$PACK/shared/hooks" 2>/dev/null || echo "fail")"
run_test "lib/common.sh functions available (incl. emit_continue + conv_id)" "ok" "$RESULT"

RESULT="$(HERE="$PACK/shared/hooks" bash -c 'source "$0/lib/common.sh" && emit_allow' "$PACK/shared/hooks" | jq -r 'has("permission") and .permission=="allow"')"
run_test "emit_allow uses permission key" "true" "$RESULT"
RESULT="$(HERE="$PACK/shared/hooks" bash -c 'source "$0/lib/common.sh" && emit_context "x"' "$PACK/shared/hooks" | jq -r 'has("additional_context")')"
run_test "emit_context uses additional_context key" "true" "$RESULT"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
echo '{"tool_name":"Write","tool_input":{"file_path":"docs/security.md","content":"# blocks rm -rf / literally\n"}}' | bash "$PACK/shared/hooks/pre_tool_use.sh" | jq -r '.permission // "allow"' > /tmp/_exec_test_out 2>/dev/null || true
RESULT="$(cat /tmp/_exec_test_out 2>/dev/null || echo allow)"
run_test "pre_tool_use skips destructive scan for non-executable (.md)" "allow" "$RESULT"
rm -f /tmp/_exec_test_out

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
RESULT="$(echo '{"tool_name":"Write","tool_input":{"file_path":"evil.sh","content":"rm -rf /\n"}}' | bash "$PACK/shared/hooks/pre_tool_use.sh" | jq -r '.permission // "allow"')"
run_test "pre_tool_use still scans executable files (.sh)" "deny" "$RESULT"
