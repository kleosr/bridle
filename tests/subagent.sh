#!/usr/bin/env bash
# Subagent hooks (F-02): subagentStop merges modified_files into conversation allowed_files.

rm -rf "$PACK/state"
CONV="conv-parent-001"
STATE_DIR="$PACK/state/$CONV"
mkdir -p "$STATE_DIR"
printf 'src/declared.ts\n' > "$STATE_DIR/allowed_files.md"

cat "$PACK/tests/fixtures/subagentStop.json" | bash "$PACK/hooks/subagent_stop.sh" >/dev/null 2>&1 || true

HAS_DECLARED="$(grep -c 'src/declared.ts' "$STATE_DIR/allowed_files.md" 2>/dev/null || echo 0)"
HAS_AUTH="$(grep -c 'src/auth.ts' "$STATE_DIR/allowed_files.md" 2>/dev/null || echo 0)"
HAS_UTILS="$(grep -c 'src/utils.ts' "$STATE_DIR/allowed_files.md" 2>/dev/null || echo 0)"
run_test "subagentStop preserves pre-existing allowed_files" "1" "$HAS_DECLARED"
run_test "subagentStop merged modified_file src/auth.ts" "1" "$HAS_AUTH"
run_test "subagentStop merged modified_file src/utils.ts" "1" "$HAS_UTILS"

rm -rf "$PACK/state"

RESULT="$(echo '{"file_path":"/home/user/.env","hook_event_name":"beforeReadFile"}' | bash "$PACK/hooks/before_read_file.sh" | jq -r '.action // .permission // "allow"')"
run_test "before_read_file blocks .env from model context" "deny" "$RESULT"

RESULT="$(echo '{"file_path":"/home/user/src/app.ts","hook_event_name":"beforeReadFile"}' | bash "$PACK/hooks/before_read_file.sh" | jq -r 'if . == {} then "allow" else (.action // .permission // "allow") end')"
run_test "before_read_file allows normal source" "allow" "$RESULT"

rm -rf "$PACK/state"
mkdir -p "$PACK/state"
RESULT="$(echo '{"command":"npm test","exit_code":0,"conversation_id":"conv-shell-001"}' | bash "$PACK/hooks/after_shell.sh" | jq -r 'if . == {} then "quiet" else "noisy" end')"
run_test "after_shell emits quiet (audit side-effect)" "quiet" "$RESULT"
SHELL_LOG_LINE="$(grep -c 'SHELL | exit=0' "$PACK/state/conv-shell-001/session.log" 2>/dev/null || echo 0)"
run_test "after_shell logged to conversation session.log" "1" "$SHELL_LOG_LINE"
rm -rf "$PACK/state"
