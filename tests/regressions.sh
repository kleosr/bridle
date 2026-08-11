#!/usr/bin/env bash
# Sourced by run.sh. Regression tests for past bug fixes (HANDOFF archive, compaction, TOCTOU, etc.

rm -rf "$PACK/state"
printf '# HANDOFF — Session State\n\n## Active Objective\n\nold task\n\n## Archived\n\n- Previous session note\n' > "$PACK/HANDOFF.md"
cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/shared/hooks/stop_gate.sh" >/dev/null 2>&1 || true
RESULT="$(grep -q 'Previous session note' "$PACK/HANDOFF.md" && echo "ok" || echo "fail")"
run_test "HANDOFF preserves prior Archived history" "ok" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/stop_no_intent.json" | bash "$PACK/shared/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate followup on missing INTENT" "followup" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/shared/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate accepts valid INTENT" "accept" "$RESULT"

# Cursor-native stop: transcript_path JSONL, no messages array
rm -rf "$PACK/state"
TP="$(mktemp)"
printf '%s\n' \
  '{"role":"user","content":"fix the bug"}' \
  '{"role":"assistant","content":"All done without INTENT."}' > "$TP"
RESULT="$(echo "{\"status\":\"completed\",\"loop_count\":0,\"transcript_path\":\"$TP\"}" | bash "$PACK/shared/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate audits from transcript_path JSONL" "followup" "$RESULT"
rm -f "$TP"

rm -rf "$PACK/state"
TP="$(mktemp)"
printf '%s\n' \
  '{"role":"user","content":"fix the bug"}' \
  '{"role":"assistant","content":"INTENT: fix docs\nedit:README.md\nDone-when:\n- file updated\nDone-when: met"}' > "$TP"
RESULT="$(echo "{\"status\":\"completed\",\"loop_count\":0,\"transcript_path\":\"$TP\"}" | bash "$PACK/shared/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate accepts valid INTENT via transcript_path" "accept" "$RESULT"
rm -f "$TP"

rm -rf "$PACK/state"
RESULT="$(echo '{"status":"completed","loop_count":0}' | bash "$PACK/shared/hooks/stop_gate.sh" | jq -r 'if . == {} then "quiet" else "other" end')"
run_test "stop_gate fail-open quiet when transcript_path absent" "quiet" "$RESULT"
RESULT="$(grep -c 'no messages array and no transcript_path' "$PACK/state/session.log" 2>/dev/null || echo 0)"
RESULT="${RESULT//[!0-9]}"; [[ -z "$RESULT" ]] && RESULT=0
run_test "stop_gate logs loud ERROR when transcript missing" "1" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"status":"completed","transcript_path":"/nonexistent/path/transcript.jsonl"}' | bash "$PACK/shared/hooks/stop_gate.sh" | jq -r 'if . == {} then "quiet" else "other" end')"
run_test "stop_gate fail-open on unreadable transcript_path" "quiet" "$RESULT"
RESULT="$(grep -c 'transcript missing/unreadable' "$PACK/state/session.log" 2>/dev/null || echo 0)"
RESULT="${RESULT//[!0-9]}"; [[ -z "$RESULT" ]] && RESULT=0
run_test "stop_gate logs loud ERROR on unreadable transcript" "1" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"status":"completed","messages":[{"role":"assistant","content":"```bash\necho INTENT: poison\nDone-when: met\nedit:a\n```"}]}' | bash "$PACK/shared/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "stop_gate ignores code-fence poison" "followup" "$RESULT"

LONG_HANDOFF="$(mktemp)"
for i in $(seq 1 200); do echo "line $i"; done > "$LONG_HANDOFF"
RESULT="$(HERE="$PACK/shared/hooks" bash -c '
  source "$0/lib/common.sh"; resolve_root
  HANDOFF="'"$LONG_HANDOFF"'"
  HL="$(wc -l < "$HANDOFF" 2>/dev/null || echo 0)"
  if [[ "$HL" -gt 180 ]]; then echo "compact"; else echo "skip"; fi
' "$PACK/shared/hooks" 2>/dev/null || echo "error")"
rm -f "$LONG_HANDOFF"
run_test "HANDOFF compaction gate fires >180 lines" "compact" "$RESULT"

R1_HANDOFF_BAK="$(cat "$PACK/HANDOFF.md" 2>/dev/null || true)"
rm -rf "$PACK/state"
printf '# HANDOFF — Session State\n\n## Active Objective\n\nold\n\n## Archived\n\n- old note\n\n<!-- COMPACTION PROTOCOL\nsome rules\n-->\n\n(Older context compacted here when active sections exceed ~150 lines.)\n' > "$PACK/HANDOFF.md"
cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/shared/hooks/stop_gate.sh" >/dev/null 2>&1 || true
PROTO_COUNT="$(grep -c 'COMPACTION PROTOCOL' "$PACK/HANDOFF.md" 2>/dev/null || true)"
PROTO_COUNT="${PROTO_COUNT//[!0-9]}"; [[ -z "$PROTO_COUNT" ]] && PROTO_COUNT=0
PLACEHOLDER_COUNT="$(grep -c 'Older context compacted here' "$PACK/HANDOFF.md" 2>/dev/null || true)"
PLACEHOLDER_COUNT="${PLACEHOLDER_COUNT//[!0-9]}"; [[ -z "$PLACEHOLDER_COUNT" ]] && PLACEHOLDER_COUNT=0
if [[ "$PROTO_COUNT" -eq 1 && "$PLACEHOLDER_COUNT" -eq 1 ]]; then
  echo "[pass] accept() does not duplicate COMPACTION PROTOCOL"; PASS=$((PASS + 1))
else
  echo "[fail] accept() duplicated COMPACTION PROTOCOL (proto=$PROTO_COUNT placeholder=$PLACEHOLDER_COUNT)"; FAIL=$((FAIL + 1))
fi
[[ -n "$R1_HANDOFF_BAK" ]] && printf '%s' "$R1_HANDOFF_BAK" >"$PACK/HANDOFF.md"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
printf 'GARBAGE\n' > "$PACK/state/outcomes.md"
RESULT="$(cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/shared/hooks/stop_gate.sh" 2>/dev/null | jq -r 'if .followup_message then "followup" else "accept" end' 2>/dev/null || echo "crash")"
run_test "stop_gate tolerates corrupt outcomes.md" "accept" "$RESULT"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
printf '' > "$PACK/state/session_ts"
printf '1\n' > "$PACK/state/outcomes.md"
RESULT="$(cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/shared/hooks/stop_gate.sh" 2>/dev/null | jq -r 'if .followup_message then "followup" else "accept" end' 2>/dev/null || echo "crash")"
run_test "stop_gate tolerates empty session_ts" "accept" "$RESULT"

VELOCITY_SRC="$(sed -n '/velocity_bump/,/^}/p' "$PACK/shared/hooks/lib/shared_state.sh")"
ACQUIRE_LINE="$(printf '%s\n' "$VELOCITY_SRC" | grep -n 'acquire_lock' | head -1 | cut -d: -f1)"
GREP_LINE="$(printf '%s\n' "$VELOCITY_SRC" | grep -n 'grep -cxF' | head -1 | cut -d: -f1)"
if [[ -n "$ACQUIRE_LINE" && -n "$GREP_LINE" && "$GREP_LINE" -gt "$ACQUIRE_LINE" ]]; then
  echo "[pass] velocity count read under lock (no TOCTOU)"; PASS=$((PASS + 1))
else
  echo "[fail] velocity count read outside lock (TOCTOU present): acquire=$ACQUIRE_LINE grep=$GREP_LINE"; FAIL=$((FAIL + 1))
fi

RESULT="$(HERE="$PACK/shared/hooks" bash -c '
  count_lines() { printf "%s\n" "$1" | wc -l; }
  echo "$(count_lines "single-line")"
' 2>/dev/null | tr -d '[:space:]')"
run_test "count_lines counts single-line as 1" "1" "$RESULT"

printf '# HANDOFF — Session State\n\n## Active Objective\n\nreal task\n\n## Archived\n\n- real note\n\n<!-- COMPACTION PROTOCOL\nprotocol boilerplate line\n-->\n' > "$PACK/HANDOFF.md"
RESULT="$(echo '{}' | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("real note") and (test("COMPACTION PROTOCOL") | not)')"
run_test "session_start tail excludes COMPACTION PROTOCOL block" "true" "$RESULT"

rm -rf "$PACK/state"; mkdir -p "$PACK/state"
printf 'l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\nl10\n' > /tmp/vel_target.ts
for i in $(seq 1 15); do echo '/tmp/vel_target.ts' >> "$PACK/state/edit_velocity.log"; done
RESULT="$(echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/vel_target.ts","old_string":"l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\n","new_string":"l1"}}' | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r '.permission // "none"')"
run_test "lean_gate skips velocity deny on LOC-reducing edit" "allow" "$RESULT"
RESULT="$(echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/vel_target.ts","old_string":"l1","new_string":"l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\nl10\nl11\nl12\n"}}' | bash "$PACK/shared/hooks/lean_gate.sh" | jq -r '.permission // "none"')"
run_test "lean_gate enforces velocity on non-reducing edit" "deny" "$RESULT"
rm -f /tmp/vel_target.ts

rm -rf "$PACK/state"
printf '# HANDOFF — Session State\n\n## Current State\n\nReal session content worth keeping.\n\n## Next Actions\n\n- ship it\n' > "$PACK/HANDOFF.md"
cat "$PACK/tests/fixtures/stop_valid_intent.json" | bash "$PACK/shared/hooks/stop_gate.sh" >/dev/null 2>&1 || true
RESULT="$(grep -q 'Real session content worth keeping' "$PACK/HANDOFF.md" && echo "ok" || echo "fail")"
run_test "rules_accept preserves real HANDOFF content (no template wipe)" "ok" "$RESULT"

FS_HOME="$(mktemp -d)"
RESULT="$(HOME="$FS_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1; echo $?)"
SKILLS_OK="$(test -L "$FS_HOME/.cursor/skills/ponytail" && echo yes || echo no)"
HAS_BEFORE_SHELL="$(grep -c 'before_shell.sh' "$FS_HOME/.cursor/hooks.json" 2>/dev/null || echo 0)"
HAS_BEFORE_SHELL="${HAS_BEFORE_SHELL//[!0-9]}"; [[ -z "$HAS_BEFORE_SHELL" ]] && HAS_BEFORE_SHELL=0
rm -rf "$FS_HOME"
run_test "fleet_sync install completes on fresh HOME (orphan-loop set -e regression)" "0" "$RESULT"
run_test "fleet_sync install actually installs skills on fresh HOME" "yes" "$SKILLS_OK"
run_test "fleet_sync installs beforeShellExecution hook" "1" "$HAS_BEFORE_SHELL"

rm -rf "$PACK/state"
CHAT_OUT="$(printf '%s' '{"prompt":"gracias por la explicacion de arquitectura","hook_event_name":"beforeSubmitPrompt","conversation_id":"conv-chat-001"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh")"
RESULT="$(printf '%s' "$CHAT_OUT" | jq -r '.continue')"
run_test "chat route before_submit continues" "true" "$RESULT"
RESULT="$(cat "$PACK/state/conv-chat-001/route" 2>/dev/null || echo missing)"
run_test "chat route writes route=chat" "chat" "$RESULT"
# DUTY injection moved to sessionStart — chat must not get FILE_MAP via beforeSubmit
RESULT="$(printf '%s' "$CHAT_OUT" | jq -r 'has("additional_context") or has("additionalContext")')"
run_test "before_submit does not inject context (Cursor contract)" "false" "$RESULT"
CODE_OUT="$(printf '%s' '{"prompt":"corrige el bug en src/auth.ts","hook_event_name":"beforeSubmitPrompt","conversation_id":"conv-code-001"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh")"
RESULT="$(printf '%s' "$CODE_OUT" | jq -r '.continue')"
run_test "code route before_submit continues" "true" "$RESULT"
RESULT="$(cat "$PACK/state/conv-code-001/route" 2>/dev/null || echo missing)"
run_test "code route writes route=code" "code" "$RESULT"
STOP_OUT="$(printf '%s' '{"status":"completed","conversation_id":"conv-chat-001","messages":[{"role":"user","content":"gracias"},{"role":"assistant","content":"De nada, aqui estoy."}]}' | bash "$PACK/shared/hooks/stop_gate.sh")"
RESULT="$(printf '%s' "$STOP_OUT" | jq -r 'if . == {} then "quiet" else "followup" end')"
run_test "chat route stop accepted without INTENT" "quiet" "$RESULT"
rm -rf "$PACK/state"

printf '%s' '{"prompt":"dale nomas a eso","hook_event_name":"beforeSubmitPrompt","conversation_id":"conv-slang-001"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" >/dev/null 2>&1
printf 'src/x.ts\n' >>"$PACK/state/conv-slang-001/writes"
RESULT="$(printf '%s' '{"status":"completed","conversation_id":"conv-slang-001","messages":[{"role":"user","content":"dale nomas a eso"},{"role":"assistant","content":"Listo."}]}' | bash "$PACK/shared/hooks/stop_gate.sh" | jq -r 'if .followup_message then "followup" else "accept" end')"
run_test "chat route with writes this turn still enforces INTENT" "followup" "$RESULT"
rm -rf "$PACK/state"

mkdir -p "$PACK/state/conv-old-999" "$PACK/state/conv-fresh-1"
OLD_TS="$(date -v-3d +%Y%m%d%H%M 2>/dev/null || date -d '3 days ago' +%Y%m%d%H%M)"
touch -t "$OLD_TS" "$PACK/state/conv-old-999"
bash "$PACK/shared/hooks/fleet_dispatch.sh" --sweep >/dev/null 2>&1 || true
OLD_GONE="$(test -d "$PACK/state/conv-old-999" && echo no || echo yes)"
FRESH_KEPT="$(test -d "$PACK/state/conv-fresh-1" && echo yes || echo no)"
run_test "fleet_dispatch --sweep removes >2d conversation state" "yes" "$OLD_GONE"
run_test "fleet_dispatch --sweep keeps fresh conversation state" "yes" "$FRESH_KEPT"
rm -rf "$PACK/state"
