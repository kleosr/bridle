#!/usr/bin/env bash
# Sourced by run.sh. Hook fixture tests (agent-mode behavior).

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_code.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit_prompt emits continue:true" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | length > 0')"
run_test "session_start emits additional_context" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("DEBERES:")')"
run_test "session_start injects DEBERES duty" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("GROUNDING") and test("HANDOFF.md") and test("AGENTS.md")')"
run_test "session_start injects grounding checklist" "true" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"please fix src/auth.ts login bug"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if .continue==true and (.user_message|test("FILE_MAP nudge")) then "nudge" else "no" end')"
run_test "before_submit soft FILE_MAP nudge (continue:true)" "nudge" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"implement a login form"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if .continue==true and ((.user_message // "")|length)==0 then "clean" else "other" end')"
run_test "before_submit no nudge when no path tokens" "clean" "$RESULT"

RESULT="$(echo '{"trigger":"auto","context_usage_percent":88}' | bash "$PACK/shared/hooks/pre_compact.sh" | jq -r 'if .user_message|test("HANDOFF") then "ok" else "no" end')"
run_test "preCompact emits user_message re-Read reminder" "ok" "$RESULT"

if jq -e '.hooks.preCompact' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks.preCompact' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null \
  && jq -e '.hooks|has("sessionStart")|not' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null; then
  echo "[pass] preCompact registered globally + cloud (no sessionStart in cloud)"; PASS=$((PASS + 1))
else
  echo "[fail] preCompact registration wrong"; FAIL=$((FAIL + 1))
fi

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

if OUT="$(set +eo pipefail; bash "$PACK/shared/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_comments_jsdoc_deny.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.permission // "allow"')"
run_test "lean_gate denies JSDoc/block prose comments" "deny" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/lean_comments_machine_ok.json" | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r '.permission // "allow"')"
run_test "lean_gate allows machine-directive-only comments" "allow" "$RESULT"

rm -rf "$PACK/state"
# Projected whole-file: fragment is clean but on-disk file still has prose comments → deny
printf '%s\n' '// Narrating prose comment that must be scored on projected file.' 'export const x = 1;' 'export const y = 2;' 'export const z = 3;' 'export const w = 4;' 'export const a = 5;' 'export const b = 6;' 'export const c = 7;' 'export const d = 8;' > /tmp/lean_proj_comments.ts
RESULT="$(echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/lean_proj_comments.ts","old_string":"export const x = 1;","new_string":"export const x = 99;"}}' | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r '.permission // "allow"')"
run_test "lean_gate scores projected whole file comments (not fragment only)" "deny" "$RESULT"
rm -f /tmp/lean_proj_comments.ts

rm -rf "$PACK/state"
SOFT_BODY="$(python3 -c 'print("\n".join([f"export const v{i} = {i};" for i in range(160)]))')"
RESULT="$(jq -n --arg c "$SOFT_BODY" '{tool_name:"Write",tool_input:{file_path:"src/soft.ts",content:$c}}' | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r 'if .permission=="allow" and (.agent_message|test("SOFT LOC")) then "warn" else "no" end')"
run_test "lean_gate soft LOC allow+agent_message (>150)" "warn" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"tool_name":"Write","tool_input":{"file_path":"docs/guide.md","content":"# Title\n\nThis is a long prose doc.\n\nMore prose here.\n"}}' | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r '.permission // "allow"')"
run_test "lean_gate skips comment gate on markdown docs" "allow" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"tool_name":"Write","tool_input":{"file_path":"src/clean.ts","content":"export const authenticate = (token: string) => Boolean(token);\nexport const refresh = (token: string) => token;\n"}}' | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r '.permission // "allow"')"
run_test "lean_gate allows self-documenting source (near-zero comments)" "allow" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_secret.json" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit blocks secret/token patterns" "false" "$RESULT"

RESULT="$(echo '{"tool_name":"db_admin","tool_input":"drop database production"}' | bash "$PACK/shared/hooks/before_mcp.sh" | jq -r '.permission')"
run_test "before_mcp denies dangerous MCP patterns" "deny" "$RESULT"

RESULT="$(echo '{"tool_name":"search_docs","tool_input":"{\"q\":\"auth\"}"}' | bash "$PACK/shared/hooks/before_mcp.sh" | jq -r '.permission // "allow"')"
run_test "before_mcp allows benign MCP tool" "allow" "$RESULT"

if jq -e '.hooks.beforeTabFileRead and .hooks.beforeMCPExecution' "$PACK/shared/hooks/hooks.json" >/dev/null \
  && jq -e '.hooks|has("sessionStart")|not' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null \
  && jq -e '.hooks.preToolUse|length >= 1' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null; then
  echo "[pass] hooks.json has tab+mcp; hooks.cloud.json omits sessionStart"; PASS=$((PASS + 1))
else
  echo "[fail] cloud/tab/mcp hooks.json shape wrong"; FAIL=$((FAIL + 1))
fi

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

COMMENT_MAX="$(jq -r '.comment_ratio_max' "$PACK/shared/hooks/policy/lean.json")"
SOFT_MAX="$(jq -r '.file_loc_soft' "$PACK/shared/hooks/policy/lean.json")"
run_test "lean.json comment_ratio_max is 2 (zero-comment)" "2" "$COMMENT_MAX"
run_test "lean.json file_loc_soft is 150" "150" "$SOFT_MAX"

LOC_OK=1
for f in "$PACK"/shared/hooks/session_start.sh "$PACK"/shared/hooks/session_end.sh "$PACK"/shared/hooks/before_submit_prompt.sh "$PACK"/shared/hooks/stop_gate.sh "$PACK"/shared/hooks/lean_gate.sh "$PACK"/shared/hooks/pre_tool_use.sh "$PACK"/shared/hooks/before_shell.sh "$PACK"/shared/hooks/before_mcp.sh "$PACK"/shared/hooks/pre_compact.sh "$PACK"/shared/hooks/subagent_start.sh "$PACK"/shared/hooks/subagent_stop.sh "$PACK"/shared/hooks/after_shell.sh "$PACK"/shared/hooks/before_read_file.sh; do
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
