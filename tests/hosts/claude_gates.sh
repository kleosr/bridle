#!/usr/bin/env bash
# Sourced by run.sh: the three gates under BRIDLE_HOST=claude (Claude Code
# PreToolUse / UserPromptSubmit output), and their registration in an
# isolated HOME.

CG_H="$(mktemp -d "${TMPDIR:-/tmp}/kleos-cg.XXXXXX")"

# cg HOOK PAYLOAD: "<exit>|<stdout>" of a gate run as Claude Code runs it.
cg() {
  local out rc=0
  out="$(printf '%s' "$2" | BRIDLE_HOST=claude bash "$PACK/shared/gate/$1" 2>/dev/null)" || rc=$?
  printf '%s|%s' "$rc" "$out"
}
cg_decision() {
  local r; r="$(cg "$1" "$2")"
  printf '%s|%s' "${r%%|*}" "$(jq -r '.hookSpecificOutput.permissionDecision // .decision // empty' <<<"${r#*|}" 2>/dev/null)"
}

run_test "claude gate: force push is denied" "0|deny" \
  "$(cg_decision before_shell.sh '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push --force origin main"},"cwd":"/tmp"}')"
run_test "claude gate: infra change asks" "0|ask" \
  "$(cg_decision before_shell.sh '{"tool_name":"Bash","tool_input":{"command":"terraform apply"},"cwd":"/tmp"}')"
run_test "claude gate: git status is silent allow" "0|" \
  "$(cg before_shell.sh '{"tool_name":"Bash","tool_input":{"command":"git status"},"cwd":"/tmp"}')"
run_test "claude gate: read of .env is denied" "0|deny" \
  "$(cg_decision before_read_file.sh '{"tool_name":"Read","tool_input":{"file_path":"/proj/.env"}}')"
run_test "claude gate: read of source is silent allow" "0|" \
  "$(cg before_read_file.sh '{"tool_name":"Read","tool_input":{"file_path":"/proj/src/a.ts"}}')"
run_test "claude gate: a secret in the prompt blocks" "0|block" \
  "$(cg_decision before_submit_prompt.sh "{\"prompt\":\"token ghp_$(printf 'Z%.0s' {1..36})\"}")"
run_test "claude gate: a clean prompt is silent allow" "0|" \
  "$(cg before_submit_prompt.sh '{"prompt":"fix the parser"}')"
run_test "claude gate: Cursor's copy of the hook defers to Cursor" "0|" \
  "$(cg before_shell.sh '{"cursor_version":"3.21","tool_input":{"command":"git push --force origin main"},"cwd":"/tmp"}')"
RESULT="$(printf '{}' | BRIDLE_HOST=nohost bash "$PACK/shared/gate/before_shell.sh" >/dev/null 2>&1 && echo 0 || echo $?)"
run_test "claude gate: a missing verdict file exits 2 (Claude denies on 2)" "2" "$RESULT"

HOME="$CG_H" bash "$PACK/shared/hosts/claude/install.sh" install >/dev/null 2>&1 || true
HOME="$CG_H" bash "$PACK/shared/hosts/claude/install.sh" install >/dev/null 2>&1 || true
RESULT="$(jq -r '[(.hooks.PreToolUse[].matcher), (.hooks.UserPromptSubmit | length), (.hooks.Stop | length)] | join(",")' "$CG_H/.claude/settings.json" 2>/dev/null)"
run_test "claude port registers each hook once across reinstalls" "Write,Bash,Read,1,1" "$RESULT"
CMD="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[0].command' "$CG_H/.claude/settings.json" 2>/dev/null)"
RESULT="$(printf '%s' '{"tool_input":{"command":"git push --force origin main"},"cwd":"/tmp"}' | HOME="$CG_H" sh -c "$CMD" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)"
run_test "claude port: the installed Bash gate denies through its registered command" "deny" "$RESULT"
HOME="$CG_H" bash "$PACK/shared/hosts/claude/install.sh" uninstall >/dev/null 2>&1 || true
RESULT="$(jq -r '.hooks // {} | length' "$CG_H/.claude/settings.json" 2>/dev/null)|$(test -e "$CG_H/.claude/hooks/bridle" && echo present || echo gone)"
run_test "claude port uninstall removes the gate entries and tree" "0|gone" "$RESULT"
rm -rf "$CG_H"
