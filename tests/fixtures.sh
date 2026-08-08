#!/usr/bin/env bash
# Sourced by run.sh. Hook fixture tests (agent-mode behavior).

RESULT="$(cat "$PACK/tests/fixtures/beforeSubmitPrompt_code.json" | bash "$PACK/hooks/before_submit_prompt.sh" | jq -r '.additionalContext | length > 0')"
run_test "before_submit_prompt emits context" "true" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/hooks/session_start.sh" | jq -r '.additionalContext | length > 0')"
run_test "session_start emits context" "true" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/preToolUse_write_small.json" | bash "$PACK/hooks/lean_gate.sh" | jq -r '.action')"
run_test "lean_gate allows small write" "allow" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_coupling_high.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.action // "allow"')"
run_test "lean_gate denies high coupling" "deny" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_nesting_deep.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.action // "allow"')"
run_test "lean_gate denies deep nesting" "deny" "$RESULT"

if OUT="$(set +eo pipefail; bash "$PACK/hooks/lean_gate.sh" < "$PACK/tests/fixtures/lean_complexity_high.json" 2>/dev/null)"; then :; fi
RESULT="$(echo "$OUT" | jq -r '.action // "allow"')"
run_test "lean_gate denies high complexity" "deny" "$RESULT"

RESULT="$(echo '{"tool_name":"Read","tool_input":{"file_path":"x"}}' | bash "$PACK/hooks/pre_tool_use.sh" | jq -r 'if . == {} then "pass" else .action end')"
run_test "pre_tool_use allows Read" "pass" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/preToolUse_bash_destructive.json" | bash "$PACK/hooks/pre_tool_use.sh" | jq -r '.action')"
run_test "pre_tool_use blocks destructive root-delete" "deny" "$RESULT"

RESULT="$(echo '{"tool_name":"Bash","hook_event_name":"preToolUse","tool_input":{"command":"rm -rf /"}}' | bash "$PACK/hooks/pre_tool_use.sh" | jq -r '.action // "none"')"
run_test "pre_tool_use Cursor-only deny even with hook_event_name" "deny" "$RESULT"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
echo 'src/db.ts' > "$PACK/state/allowed_files.md"
RESULT="$(cat "$PACK/tests/fixtures/preToolUse_scope_expansion.json" | bash "$PACK/hooks/pre_tool_use.sh" | jq -r '.action // "allow"')"
run_test "pre_tool_use scope expansion uses allow action (was warn)" "allow" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"implement a login form"}' | bash "$PACK/hooks/before_submit_prompt.sh" | jq -r '.additionalContext | test("CONSTRAINTS:")')"
run_test "before_submit reminds constraints on unbound task" "true" "$RESULT"

rm -rf "$PACK/state"
echo '{"tool_name":"Write","tool_input":{"file_path":"x.ts","content":"const a=1;\n"}}' | bash "$PACK/hooks/lean_gate.sh" >/dev/null 2>&1 || true
RESULT="$([[ -f "$PACK/state/session.log" ]] && grep -q 'lean_gate' "$PACK/state/session.log" && echo "ok" || echo "fail")"
run_test "shared_state logs lean_gate events" "ok" "$RESULT"

if ! grep -Rq --include='*.sh' 'updated_input' "$PACK/hooks/" 2>/dev/null && [[ ! -e "$PACK/hooks/kleos-gate" ]]; then
  echo "[pass] no updated_input / Rust gate"; PASS=$((PASS + 1))
else
  echo "[fail] updated_input or Rust gate found"; FAIL=$((FAIL + 1))
fi

LOC_OK=1
for f in "$PACK"/hooks/session_start.sh "$PACK"/hooks/session_end.sh "$PACK"/hooks/before_submit_prompt.sh "$PACK"/hooks/stop_gate.sh "$PACK"/hooks/lean_gate.sh "$PACK"/hooks/pre_tool_use.sh "$PACK"/hooks/subagent_start.sh "$PACK"/hooks/subagent_stop.sh "$PACK"/hooks/after_shell.sh "$PACK"/hooks/before_read_file.sh; do
  n="$(wc -l < "$f")"
  [[ "$n" -le 80 ]] || { LOC_OK=0; break; }
done
if [[ "$LOC_OK" -eq 1 ]]; then
  echo "[pass] event hooks LOC ≤ 80"; PASS=$((PASS + 1))
else
  echo "[fail] event hook exceeds 80 LOC: ${f#$PACK/} ($n)"; FAIL=$((FAIL + 1))
fi

RESULT="$(HERE="$PACK/hooks" bash -c 'source "$0/lib/common.sh" && resolve_root && type emit_allow >/dev/null && type emit_deny >/dev/null && type emit_followup >/dev/null && type acquire_lock >/dev/null && type is_agent_mode >/dev/null && type extract_conv_id >/dev/null && type state_dir >/dev/null && echo "ok"' "$PACK/hooks" 2>/dev/null || echo "fail")"
run_test "lib/common.sh functions available (incl. conv_id + state_dir)" "ok" "$RESULT"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
echo '{"tool_name":"Write","tool_input":{"file_path":"docs/security.md","content":"# blocks rm -rf / literally\n"}}' | bash "$PACK/hooks/pre_tool_use.sh" | jq -r '.action // "allow"' > /tmp/_exec_test_out 2>/dev/null || true
RESULT="$(cat /tmp/_exec_test_out 2>/dev/null || echo allow)"
run_test "pre_tool_use skips destructive scan for non-executable (.md)" "allow" "$RESULT"
rm -f /tmp/_exec_test_out

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
RESULT="$(echo '{"tool_name":"Write","tool_input":{"file_path":"evil.sh","content":"rm -rf /\n"}}' | bash "$PACK/hooks/pre_tool_use.sh" | jq -r '.action // "allow"')"
run_test "pre_tool_use still scans executable files (.sh)" "deny" "$RESULT"
