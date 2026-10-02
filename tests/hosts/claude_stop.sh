#!/usr/bin/env bash
# Sourced by run.sh: the Claude Code Stop hook, driven with synthetic
# transcripts, and its registration in an isolated HOME.

STOP_H="$(mktemp -d "${TMPDIR:-/tmp}/kleos-stop.XXXXXX")"
STOP_HOOK="$PACK/hosts/claude/before_stop.sh"
STOP_PROJ="$STOP_H/proj"; mkdir -p "$STOP_PROJ"; git -C "$STOP_PROJ" init -q 2>/dev/null

tr_user() { jq -cn --arg t "$1" '{type:"user",message:{role:"user",content:$t}}'; }
tr_use() { jq -cn --arg id "$1" --arg n "$2" --argjson i "$3" '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:$id,name:$n,input:$i}]}}'; }
tr_res() { jq -cn --arg id "$1" --argjson e "${2:-false}" '{type:"user",message:{role:"user",content:[{type:"tool_result",tool_use_id:$id,is_error:$e,content:"x"}]}}'; }
tr_edit() { tr_use "$1" Edit "$(jq -cn --arg f "$2" --arg o "${3:-a}" --arg n "${4:-b}" '{file_path:$f,old_string:$o,new_string:$n}')"; tr_res "$1"; }
tr_write() { tr_use "$1" Write "$(jq -cn --arg f "$2" '{file_path:$f,content:"x"}')"; tr_res "$1"; }
tr_verify() { tr_use "$1" Bash '{"command":"bash tests/run.sh"}'; tr_res "$1" "${2:-false}"; }

# stop_turn TRANSCRIPT [ACTIVE]: exit code of the hook for that transcript.
stop_turn() {
  printf '%s\n' "$1" >"$STOP_H/t.jsonl"
  jq -cn --arg c "$STOP_PROJ" --arg t "$STOP_H/t.jsonl" --argjson a "${2:-false}" \
    '{stop_hook_active:$a,cwd:$c,transcript_path:$t,session_id:"s"}' \
    | HOME="$STOP_H" bash "$STOP_HOOK" 2>/dev/null && echo 0 || echo $?
}

ASK="$(tr_user 'fix the parser')"
EDITED="$ASK"$'\n'"$(tr_edit e1 "$STOP_PROJ/parse.ts")"
run_test "stop hook blocks an edit with no verification" "2" "$(stop_turn "$EDITED")"
RESULT="$(jq -sr 'map(select(.blocked and .verified == "none" and (.files | length) == 1)) | length' "$STOP_H/.claude/state/bridle-turns.jsonl" 2>/dev/null)"
run_test "stop hook logs the blocked turn for retuning" "1" "$RESULT"
run_test "stop hook passes an edit followed by a green verify" "0" "$(stop_turn "$EDITED"$'\n'"$(tr_verify v1)")"
run_test "stop hook blocks when the last verify was red" "2" "$(stop_turn "$EDITED"$'\n'"$(tr_verify v1 true)")"
run_test "regression: curl after an edit is not verification" "2" "$(stop_turn "$EDITED"$'\n'"$(tr_use c1 Bash '{"command":"curl -s localhost:3000"}')"$'\n'"$(tr_res c1)")"
run_test "stop hook requires verify after the last edit, not before it" "2" "$(stop_turn "$ASK"$'\n'"$(tr_verify v1)"$'\n'"$(tr_edit e1 "$STOP_PROJ/parse.ts")")"
run_test "stop hook exempts docs-only edits from verification" "0" "$(stop_turn "$ASK"$'\n'"$(tr_edit e1 "$STOP_PROJ/README.md")")"
run_test "stop hook ignores edits outside the project" "0" "$(stop_turn "$ASK"$'\n'"$(tr_edit e1 /tmp/elsewhere.ts)")"
run_test "regression: a failed edit is not an edit" "0" "$(stop_turn "$ASK"$'\n'"$(tr_use e1 Edit '{"file_path":"'"$STOP_PROJ"'/parse.ts","old_string":"a","new_string":"b"}')"$'\n'"$(tr_res e1 true)")"
run_test "regression: edits from an earlier turn do not leak into the next" "0" "$(stop_turn "$EDITED"$'\n'"$(tr_user 'thanks, what changed?')")"
run_test "stop hook lets a read-only turn finish" "0" "$(stop_turn "$ASK"$'\n'"$(tr_use r1 Read '{"file_path":"x"}')")"
run_test "regression: stop_hook_active ends the loop" "0" "$(stop_turn "$EDITED" true)"

BIG_OLD="$(jq -rn '[range(125) | "a\(.)"] | join("\n")')"
BIG_NEW="$(jq -rn '[range(125) | "b\(.)"] | join("\n")')"
run_test "stop hook flags a footprint over the production-line budget" "2" "$(stop_turn "$ASK"$'\n'"$(tr_edit e1 "$STOP_PROJ/big.ts" "$BIG_OLD" "$BIG_NEW")"$'\n'"$(tr_verify v1)")"
run_test "stop hook does not count test files toward the line budget" "0" "$(stop_turn "$ASK"$'\n'"$(tr_edit e1 "$STOP_PROJ/tests/big.test.ts" "$BIG_OLD" "$BIG_NEW")"$'\n'"$(tr_verify v1)")"
TWO_NEW="$ASK"$'\n'"$(tr_write w1 "$STOP_PROJ/a.sh")"$'\n'"$(tr_write w2 "$STOP_PROJ/b.sh")"
run_test "stop hook allows two new production files" "0" "$(stop_turn "$TWO_NEW"$'\n'"$(tr_verify v1)")"
run_test "stop hook flags a third new production file" "2" "$(stop_turn "$TWO_NEW"$'\n'"$(tr_write w3 "$STOP_PROJ/c.sh")"$'\n'"$(tr_verify v1)")"

printf 'export const x = 1\n' >"$STOP_PROJ/orphan-thing.ts"
ORPHAN="$ASK"$'\n'"$(tr_write w1 "$STOP_PROJ/orphan-thing.ts")"$'\n'"$(tr_verify v1)"
run_test "stop hook blocks a new source file nothing references" "2" "$(stop_turn "$ORPHAN")"
printf "import { x } from './orphan-thing'\n" >"$STOP_PROJ/consumer.ts"
run_test "stop hook passes a new source file once it is imported" "0" "$(stop_turn "$ORPHAN")"

RESULT="$(printf 'not json' | HOME="$STOP_H" bash "$STOP_HOOK" >/dev/null 2>&1 && echo 0 || echo $?)"
run_test "stop hook fails open on a malformed payload" "0" "$RESULT"
RESULT="$(jq -cn --arg c "$STOP_PROJ" '{stop_hook_active:false,cwd:$c,transcript_path:"/nonexistent"}' | HOME="$STOP_H" bash "$STOP_HOOK" >/dev/null 2>&1 && echo 0 || echo $?)"
run_test "stop hook fails open when the transcript is missing" "0" "$RESULT"

HOME="$STOP_H" bash "$PACK/hosts/claude/install.sh" install >/dev/null 2>&1 || true
RESULT="$(jq -r '[.hooks.Stop[].hooks[].command | contains("bridle_before_stop.sh")] | join(",")' "$STOP_H/.claude/settings.json" 2>/dev/null)"
run_test "claude port registers the Stop hook without a matcher" "true" "$RESULT"
RESULT="$(test -x "$STOP_H/.claude/hooks/bridle_before_stop.sh" && echo yes || echo no)"
run_test "claude port installs the Stop hook script executable" "yes" "$RESULT"
jq '.hooks.Stop += [{hooks: [{type: "command", command: "echo mine"}]}]' "$STOP_H/.claude/settings.json" >"$STOP_H/s.json" && mv "$STOP_H/s.json" "$STOP_H/.claude/settings.json"
HOME="$STOP_H" bash "$PACK/hosts/claude/install.sh" install >/dev/null 2>&1 || true
RESULT="$(jq -r '.hooks.Stop | length' "$STOP_H/.claude/settings.json" 2>/dev/null)"
run_test "regression: reinstall keeps one bridle Stop entry beside the user's" "2" "$RESULT"
HOME="$STOP_H" bash "$PACK/hosts/claude/install.sh" uninstall >/dev/null 2>&1 || true
RESULT="$(jq -r '[.hooks.Stop[].hooks[].command] | join(",")' "$STOP_H/.claude/settings.json" 2>/dev/null)"
run_test "claude port uninstall removes only its own Stop hook" "echo mine" "$RESULT"
RESULT="$(test -e "$STOP_H/.claude/hooks/bridle_before_stop.sh" && echo present || echo gone)"
run_test "claude port uninstall removes the Stop hook script" "gone" "$RESULT"

CS_HOOK="$PACK/hosts/cursor/verdict.sh"
CS_PROJ="$STOP_H/cursor-proj"
mkdir -p "$CS_PROJ"
git -C "$CS_PROJ" init -q
printf '%s\n' 'export function ok() { return 1; }' >"$CS_PROJ/clean.ts"
git -C "$CS_PROJ" add clean.ts
git -C "$CS_PROJ" -c user.name=t -c user.email=t@t commit -qm base
cs_run() {
  jq -cn --arg r "$CS_PROJ" --argjson st "${2:-null}" \
    '{workspace_roots:[$r], status:(if $st == null then "completed" else $st end)}' \
    | bash "$CS_HOOK" turn-check 2>/dev/null
}
run_test "cursor stop turn-check passes a clean diff" "{}" "$(cs_run)"
printf '%s\n' '// ==========' >>"$CS_PROJ/clean.ts"
run_test "cursor stop turn-check emits followup on gate errors" "followup" \
  "$(cs_run | jq -r 'if .followup_message then "followup" else "none" end' 2>/dev/null)"
CS_ABORT="$STOP_H/cursor-abort"
mkdir -p "$CS_ABORT"
git -C "$CS_ABORT" init -q
printf '%s\n' 'export function ok() { return 1; }' >"$CS_ABORT/clean.ts"
git -C "$CS_ABORT" add clean.ts
git -C "$CS_ABORT" -c user.name=t -c user.email=t@t commit -qm base
run_test "cursor stop turn-check ignores aborted status" "{}" \
  "$(jq -cn --arg r "$CS_ABORT" '{workspace_roots:[$r],status:"aborted"}' | bash "$CS_HOOK" turn-check 2>/dev/null)"

if command -v node >/dev/null 2>&1; then
  mkdir -p "$STOP_H/.claude/skills/code-architecture/scripts"
  cp "$PACK/skills/code-architecture/scripts/quality-gate.mjs" "$STOP_H/.claude/skills/code-architecture/scripts/quality-gate.mjs"
  printf '%s\n' 'export function base() { return 1; }' >"$STOP_PROJ/seed.ts"
  git -C "$STOP_PROJ" add seed.ts
  git -C "$STOP_PROJ" -c user.name=t -c user.email=t@t commit -qm seed 2>/dev/null || true
  printf '%s\n' 'export function ok() { return 1; }' >"$STOP_PROJ/gate.ts"
  printf '%s\n' '// TODO fix' >>"$STOP_PROJ/gate.ts"
  QG_TRAN="$ASK"$'\n'"$(tr_write w1 "$STOP_PROJ/gate.ts")"$'\n'"$(tr_verify v1)"
  run_test "stop hook blocks when quality-gate fails on diff-added lines" "2" "$(stop_turn "$QG_TRAN")"
fi

rm -rf "$STOP_H"
