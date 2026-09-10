#!/usr/bin/env bash
# Hook edge cases: malformed/missing payload, spaces, empty command, missing policy file.

RESULT="$(printf '%s' 'not json at all' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if has("continue") then (.continue|tostring) else "missing" end')"
run_test "before_submit malformed JSON blocks (continue:false)" "false" "$RESULT"

RESULT="$(printf '\n' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r 'if has("continue") then (.continue|tostring) else "missing" end')"
run_test "before_submit empty stdin blocks (failClosed:true)" "false" "$RESULT"

RESULT="$(echo '{}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit empty prompt continues" "true" "$RESULT"

RESULT="$(echo '{}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "allow"')"
run_test "before_shell empty command allows" "allow" "$RESULT"

RESULT="$(echo '{"command":""}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "allow"')"
run_test "before_shell blank command allows" "allow" "$RESULT"

SP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kleos-sp.XXXXXX")"
SP_FILE="$SP_DIR/my secrets.pem"
touch "$SP_FILE"
RESULT="$(jq -n --arg p "$SP_FILE" '{file_path:$p}' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "allow"')"
rm -rf "$SP_DIR"
run_test "before_read_file blocks path with spaces (.pem)" "deny" "$RESULT"

RESULT="$(echo '{}' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "none"')"
run_test "before_read_file missing file_path allows" "allow" "$RESULT"

EDGE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-edge.XXXXXX")"
mkdir -p "$EDGE_HOME/.cursor/hooks/lib"
cp "$PACK/shared/hooks/before_submit_prompt.sh" "$EDGE_HOME/.cursor/hooks/"
cp "$PACK/shared/hooks/lib/common.sh" "$EDGE_HOME/.cursor/hooks/lib/"
rm -f "$EDGE_HOME/.cursor/hooks/policy/secret_tokens.ere" 2>/dev/null || true
RESULT="$(echo '{"prompt":"ghp_abcdefghijklmnopqrstuvwxyz0123456789"}' \
  | HOME="$EDGE_HOME" bash "$EDGE_HOME/.cursor/hooks/before_submit_prompt.sh" | jq -r '.continue')"
rm -rf "$EDGE_HOME"
run_test "before_submit without policy file blocks (failClosed)" "false" "$RESULT"

RESULT="$(echo '{"command":{"nested":"rm -rf /"}}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "before_shell non-string command denies" "deny" "$RESULT"

RESULT="$(echo '{"tool_input":{"command":"rm -rf /"}}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "before_shell nested tool_input.command still gates" "deny" "$RESULT"

PATH_MISS="$(mktemp -d "${TMPDIR:-/tmp}/kleos-nojq.XXXXXX")"
printf '%s\n' '#!/bin/sh' 'exit 127' >"$PATH_MISS/jq"
chmod +x "$PATH_MISS/jq"
RESULT="$(echo '{"command":"ls"}' | PATH="$PATH_MISS:$PATH" bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
rm -rf "$PATH_MISS"
run_test "before_shell missing working jq denies" "deny" "$RESULT"

# Hook interruption under signal is not tested here — no deterministic observable
# outcome in this harness (see docs/_archive/engineering-rules-audit.md limitations).
