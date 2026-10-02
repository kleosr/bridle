#!/usr/bin/env bash
# Sourced by run.sh: the three gates under BRIDLE_HOST=claude (Claude Code
# PreToolUse / UserPromptSubmit output), and their registration in an
# isolated HOME.

CG_H="$(mktemp -d "${TMPDIR:-/tmp}/kleos-cg.XXXXXX")"

# cg HOOK PAYLOAD: "<exit>|<stdout>" of a gate run as Claude Code runs it.
cg() {
  local out rc=0
  out="$(printf '%s' "$2" | BRIDLE_HOST=claude bash "$PACK/hooks/$1" 2>/dev/null)" || rc=$?
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
RESULT="$(printf '{}' | BRIDLE_HOST=nohost bash "$PACK/hooks/before_shell.sh" >/dev/null 2>&1 && echo 0 || echo $?)"
run_test "claude gate: a missing verdict file exits 2 (Claude denies on 2)" "2" "$RESULT"

HOME="$CG_H" bash "$PACK/hosts/claude/install.sh" install >/dev/null 2>&1 || true
HOME="$CG_H" bash "$PACK/hosts/claude/install.sh" install >/dev/null 2>&1 || true
RESULT="$(jq -r '[(.hooks.PreToolUse[].matcher), (.hooks.UserPromptSubmit | length), (.hooks.Stop | length)] | join(",")' "$CG_H/.claude/settings.json" 2>/dev/null)"
run_test "claude port registers each hook once across reinstalls" "Write|Edit|MultiEdit,Bash,Read,1,1" "$RESULT"
CG_W="$CG_H/.claude/hooks/bridle_before_write.sh"
cg_edit() {
  jq -n --arg c "$CG_H/proj" --arg t "$1" --arg f "$2" '{cwd:$c,tool_name:$t,tool_input:{file_path:$f,old_string:"a",new_string:"b"}}' \
    | HOME="$CG_H" XDG_CONFIG_HOME="" bash "$CG_W" 2>/dev/null && echo 0 || echo $?
}
mkdir -p "$CG_H/proj"; echo a >"$CG_H/proj/a.ts"
run_test "regression: claude Edit of the installed settings is denied" "2" "$(cg_edit Edit "$CG_H/.claude/settings.json")"
run_test "regression: claude Write into the installed hooks is denied" "2" "$(cg_edit Write "$CG_H/.claude/hooks/x.sh")"
run_test "regression: claude Edit of the opencode plugin is denied" "2" "$(cg_edit Edit "$CG_H/.config/opencode/plugin/bridle.js")"
run_test "claude Edit of an existing project file is allowed" "0" "$(cg_edit Edit "$CG_H/proj/a.ts")"
GROW="$CG_H/proj/grow.ts"
{ for _ in $(seq 1 299); do echo 'const x = 1;'; done; } >"$GROW"
cg_edit_payload() {
  jq -n --arg c "$CG_H/proj" --arg t "$1" --arg f "$2" --arg o "$3" --arg n "$4" \
    '{cwd:$c,tool_name:$t,tool_input:{file_path:$f,old_string:$o,new_string:$n}}' \
    | HOME="$CG_H" XDG_CONFIG_HOME="" bash "$CG_W" 2>/dev/null && echo 0 || echo $?
}
LAST="$(tail -n 1 "$GROW")"
run_test "regression: Edit that grows a file past 300 lines is denied" "2" \
  "$(cg_edit_payload Edit "$GROW" "$LAST" "$LAST"$'\n'"const y = 2;"$'\n'"const z = 3;")"
LEGACY="$CG_H/proj/legacy.ts"
{ for _ in $(seq 1 710); do echo 'const x = 1;'; done; } >"$LEGACY"
LEG_LAST="$(tail -n 1 "$LEGACY")"
run_test "Edit growth past 300 is allowed on a legacy file over 700 lines" "0" \
  "$(cg_edit_payload Edit "$LEGACY" "$LEG_LAST" "$LEG_LAST"$'\n'"const y = 2;")"
SHRINK="$CG_H/proj/shrink.ts"
{ for _ in $(seq 1 320); do echo 'const x = 1;'; done; } >"$SHRINK"
run_test "Edit that shrinks a file over 300 lines is allowed" "0" \
  "$(cg_edit_payload Edit "$SHRINK" "const x = 1;" "")"
CURSOR_BIG="$CG_H/proj/cursor-big.ts"
{ for _ in $(seq 1 299); do echo 'const x = 1;'; done; } >"$CURSOR_BIG"
CUR_BODY="$(cat "$CURSOR_BIG")"$'\n'"const y = 2;"$'\n'"const z = 3;"
RESULT="$(jq -n --arg r "$CG_H/proj" --arg f "$CURSOR_BIG" --arg b "$CUR_BODY" \
  '{cursor_version:"3.21",workspace_roots:[$r],tool_name:"Write",tool_input:{file_path:$f,content:$b}}' \
  | HOME="$CG_H" bash "$CG_W" 2>/dev/null && echo 0 || echo $?)"
run_test "regression: Cursor Write that grows a file past 300 lines is denied" "2" "$RESULT"
cg_cursor_write() {
  jq -n --arg r "$CG_H/proj" --arg f "$1" --arg b "$2" \
    '{cursor_version:"3.21",workspace_roots:[$r],tool_name:"Write",tool_input:{file_path:$f,content:$b}}' \
    | HOME="$CG_H" bash "$CG_W" 2>/dev/null && echo 0 || echo $?
}
printf '%s\n' '// keep' 'const a = 1;' >"$CG_H/proj/cw.ts"
run_test "regression: Cursor Write that adds a comment to an existing file is denied" "2" \
  "$(cg_cursor_write "$CG_H/proj/cw.ts" $'// keep\n// why\nconst a = 2;')"
run_test "Cursor Write that keeps an existing comment is allowed" "0" \
  "$(cg_cursor_write "$CG_H/proj/cw.ts" $'// keep\nconst a = 2;')"
jq -rn '[range(4000) | "const v\(.) = \(.);"] | join("\n")' >"$CG_H/proj/huge.ts"
run_test "regression: Cursor Write of a large legacy file is compared on disk, not via argv" "0" \
  "$(cg_cursor_write "$CG_H/proj/huge.ts" "$(cat "$CG_H/proj/huge.ts")")"

cg_turn() {
  printf '%s\n' "$1" >"$CG_H/t.jsonl"
  jq -n --arg c "$CG_H/proj" --arg t "$CG_H/t.jsonl" --arg n "$2" --arg f "$3" --arg o "$4" --arg s "$5" \
    '{cwd:$c,transcript_path:$t,tool_use_id:"p1",tool_name:$n,tool_input:{file_path:$f,old_string:$o,new_string:$s,content:$s}}' \
    | HOME="$CG_H" XDG_CONFIG_HOME="" bash "$CG_W" 2>/dev/null && echo 0 || echo $?
}
cg_user() { jq -cn --arg t "$1" '{type:"user",message:{role:"user",content:$t}}'; }
cg_use() {
  jq -cn --arg n "$1" --argjson i "$2" '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"u\($n)",name:$n,input:$i}]}}'
  jq -cn --arg n "$1" '{type:"user",message:{role:"user",content:[{type:"tool_result",tool_use_id:"u\($n)",content:"x"}]}}'
}
CG_ASK="$(cg_user 'add the parser')"
run_test "regression: claude Edit that adds a comment line is denied" "2" "$(cg_turn "$CG_ASK" Edit "$CG_H/proj/a.ts" a $'// parse it\nb')"
run_test "claude Edit that keeps an existing comment is allowed" "0" "$(cg_turn "$CG_ASK" Edit "$CG_H/proj/a.ts" $'// k\na' $'// k\nb')"
run_test "regression: claude Edit adding a shell comment is denied" "2" "$(cg_turn "$CG_ASK" Edit "$CG_H/proj/a.sh" a $'# why\nb')"
CG_LANGS=""
for cg_spec in "ex:# why" "clj:;; why" "erl:% why" "ml:(* why *)" "zig:// why"; do
  CG_LANGS+="${cg_spec%%:*}=$(cg_turn "$CG_ASK" Edit "$CG_H/proj/a.${cg_spec%%:*}" a "${cg_spec#*:}"$'\nb') "
done
run_test "regression: comment-added covers Elixir, Clojure, Erlang, OCaml, and Zig" "ex=2 clj=2 erl=2 ml=2 zig=2 " "$CG_LANGS"
run_test "regression: a new Elixir file without code-architecture is denied" "2" \
  "$(cg_turn "$CG_ASK" Write "$CG_H/proj/inbox_filters.ex" "" "defmodule Inbox.Filters do end")"
CG_OLD="$(jq -rn '[range(95) | "a\(.)"] | join("\n")')"
CG_NEW="$(jq -rn '[range(95) | "b\(.)"] | join("\n")')"
CG_FULL="$CG_ASK"$'\n'"$(cg_use Edit "$(jq -cn --arg f "$CG_H/proj/a.ts" --arg o "$CG_OLD"$'\na95\na96\na97\na98\na99' --arg n "$CG_NEW"$'\nb95\nb96\nb97\nb98\nb99' '{file_path:$f,old_string:$o,new_string:$n}')")"
run_test "regression: claude keeps editing other files past 200 production lines in a turn" "0" \
  "$(cg_turn "$CG_FULL" Edit "$CG_H/proj/b.ts" $'x1\nx2\nx3\nx4\nx5\nx6' $'y1\ny2\ny3\ny4\ny5\ny6\ny7')"
RESULT="$(jq -n --arg c "$CG_H/proj" --arg f "$GROW" --arg o "$LAST" --arg n "$LAST"$'\nconst y = 2;\nconst z = 3;' \
  '{cwd:$c,tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n}}' | HOME="$CG_H" XDG_CONFIG_HOME="" bash "$CG_W" 2>&1 >/dev/null | grep -c 'Do not stop: move one job into a new module' || true)"
run_test "edit-growth deny tells the model to split the file and continue" "1" "$RESULT"
run_test "regression: claude Write of a new code file without code-architecture is denied" "2" \
  "$(cg_turn "$CG_ASK" Write "$CG_H/proj/parser.ts" "" "export const p = 1")"
run_test "claude Write of a new code file after code-architecture is allowed" "0" \
  "$(cg_turn "$CG_ASK"$'\n'"$(cg_use Skill '{"skill":"code-architecture"}')" Write "$CG_H/proj/parser.ts" "" "export const p = 1")"
run_test "regression: claude Edit of a test file without the testing skill is denied" "2" \
  "$(cg_turn "$CG_ASK" Edit "$CG_H/proj/tests/a.test.ts" a b)"
run_test "claude Edit of a test file after the testing skill is allowed" "0" \
  "$(cg_turn "$CG_ASK"$'\n'"$(cg_use Skill '{"skill":"testing"}')" Edit "$CG_H/proj/tests/a.test.ts" a b)"
: >"$CG_H/cursor-transcript.jsonl"
cg_cursor_hook() {
  printf '%s' "$2" | env -u BRIDLE_HOST HOME="$CG_H" XDG_STATE_HOME="$CG_H/state" bash "$PACK/hooks/$1" >/dev/null 2>&1 || true
}
cg_cursor_new() {
  jq -n --arg r "$CG_H/proj" --arg t "$CG_H/cursor-transcript.jsonl" --arg f "$CG_H/proj/$1" --arg b "${2:-export const p = 1}" \
    '{cursor_version:"3.21",conversation_id:"conv-1",transcript_path:$t,workspace_roots:[$r],tool_name:"Write",tool_input:{file_path:$f,content:$b}}' \
    | HOME="$CG_H" XDG_STATE_HOME="$CG_H/state" bash "$CG_W" 2>/dev/null && echo 0 || echo $?
}
CG_SUBMIT='{"hook_event_name":"beforeSubmitPrompt","conversation_id":"conv-1","prompt":"add the parser"}'
cg_cursor_hook before_submit_prompt.sh "$CG_SUBMIT"
run_test "Cursor Write of a new code file before reading code-architecture is denied" "2" "$(cg_cursor_new n1.ts)"
cg_cursor_hook before_read_file.sh '{"hook_event_name":"beforeReadFile","conversation_id":"conv-1","file_path":"/home/u/.cursor/skills/code-architecture/SKILL.md","content":"x"}'
run_test "regression: Cursor Write of a new code file after reading its SKILL.md is allowed" "0" "$(cg_cursor_new n1.ts)"
run_test "Cursor second new file in the turn is allowed" "0" "$(cg_cursor_new n2.ts)"
run_test "regression: Cursor third new file in a turn is allowed (split, do not stop)" "0" "$(cg_cursor_new n3.ts)"
cg_cursor_hook before_submit_prompt.sh "$CG_SUBMIT"
run_test "Cursor turn ledger resets its skills on the user's next prompt" "2" "$(cg_cursor_new n3.ts)"
cg_cursor_hook before_read_file.sh '{"hook_event_name":"beforeReadFile","conversation_id":"conv-1","file_path":"/home/u/.cursor/skills/code-architecture/SKILL.md","content":"x"}'
run_test "regression: Cursor Write of a 248-line new file in a fresh turn is allowed" "0" \
  "$(cg_cursor_new studio.ts "$(jq -rn '[range(248) | "export const s\(.) = \(.);"] | join("\n")')")"
run_test "Cursor keeps writing new files after 200 production lines in a turn" "0" "$(cg_cursor_new n4.ts)"
RESULT="$(jq -n --arg r "$CG_H/proj" --arg f "$CG_H/.cursor/rules/core.mdc" '{cursor_version:"3.21",workspace_roots:[$r],tool_name:"Write",tool_input:{file_path:$f,content:"x"}}' | HOME="$CG_H" bash "$CG_W" 2>/dev/null && echo 0 || echo $?)"
run_test "regression: Cursor Write into ~/.cursor/rules is denied through the Claude hook" "2" "$RESULT"
CMD="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[0].command' "$CG_H/.claude/settings.json" 2>/dev/null)"
RESULT="$(printf '%s' '{"tool_input":{"command":"git push --force origin main"},"cwd":"/tmp"}' | HOME="$CG_H" sh -c "$CMD" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)"
run_test "claude port: the installed Bash gate denies through its registered command" "deny" "$RESULT"
HOME="$CG_H" bash "$PACK/hosts/claude/install.sh" uninstall >/dev/null 2>&1 || true
RESULT="$(jq -r '.hooks // {} | length' "$CG_H/.claude/settings.json" 2>/dev/null)|$(test -e "$CG_H/.claude/hooks/bridle" && echo present || echo gone)"
run_test "claude port uninstall removes the gate entries and tree" "0|gone" "$RESULT"
rm -rf "$CG_H"
