#!/usr/bin/env bash
# Claude Code Stop: reconcile the turn's edits with the ask before "done".
# Exit 2 sends stderr back to the model; stop_hook_active ends the loop, so a
# turn is blocked at most once. Any sensor failure exits 0: a crashed check
# must not trap the session. Every turn with edits appends one line to
# ~/.claude/state/bridle-turns.jsonl, the data the budget below is retuned from.
set -uo pipefail
MAX_FILES=6
MAX_NEW_FILES=2
MAX_PROD_LINES=200
VERIFY='(^|[ ;&|(])(bash tests/run\.sh|(npm|pnpm|yarn|bun)( run)? (test|build|lint|check|typecheck)|npx? (vitest|jest|tsc|eslint|playwright)|(next|vite|astro) build|vitest|jest|pytest|unittest|tsc|eslint|biome|ruff|mypy|go (test|vet|build)|cargo (test|check|build|clippy)|deno (test|check|lint)|make (test|check)|just (test|check)|node --(test|check)|bash -n|shellcheck)([ :]|$)'
UNWIRED_SKIP='(^|/)(tests?|__tests__|scripts|bin|migrations)/|\.(test|spec|config)\.|(^|/)(index|main|page|layout|route|loading|error|not-found|template|middleware|app|server|cli|setup|conftest|__init__|__main__)\.[a-z]+$'

command -v jq >/dev/null 2>&1 || exit 0
INPUT="$(cat)"
FIELDS="$(printf '%s' "$INPUT" | jq -r '(.stop_hook_active // false), (.cwd // ""), (.transcript_path // ""), (.session_id // "")' 2>/dev/null)" || exit 0
{ read -r ACTIVE; read -r CWD; read -r TRANSCRIPT; read -r SESSION; } <<<"$FIELDS"
[[ "$ACTIVE" == false && -n "$CWD" && -f "$TRANSCRIPT" ]] || exit 0

read -r -d '' TURN_JQ <<'JQ' || true
def lines: (. // "") | rtrimstr("\n") | split("\n");
def bag: reduce .[] as $l ({}; .[$l] += 1);
def gap: if . < 0 then -. else . end;
def churn($o; $n): ($o | bag) as $a | ($n | bag) as $b
  | reduce (([$a, $b] | map(keys) | add | unique)[]) as $k (0; . + ((($a[$k] // 0) - ($b[$k] // 0)) | gap));
def size($t): if $t.name == "Edit" then churn($t.input.old_string | lines; $t.input.new_string | lines)
  elif $t.name == "Write" then ($t.input.content | lines | length)
  else ($t.input.new_source | lines | length) end;
def lead: if type == "string" then . else ([.[]? | select(.type == "text") | .text][0] // "") end;
def human: .type == "user" and (.isSidechain | not) and (.isMeta | not)
  and (.message.content | (type == "string" or all(.[]?; .type != "tool_result"))
    and (lead | (startswith("<") | not) or startswith("<command-")));
def doc: test("\\.(md|mdx|txt|rst)$");
def inert: test("(^|/)(tests?|__tests__|spec|node_modules|dist|build|generated|migrations)/|\\.(test|spec)\\.[a-z]+$|(^|/)test_[^/]*\\.py$|_test\\.(go|py)$|\\.lock$|(package-lock\\.json|pnpm-lock\\.yaml)$");
reduce inputs as $r ({edits: {}, verify: null};
  if ($r | human) then {edits: {}, verify: null}
  elif $r.isSidechain == true then .
  elif $r.type == "assistant" then
    reduce ($r.message.content[]? | select(.type == "tool_use")) as $t (.;
      if ($t.name | IN("Edit", "Write", "NotebookEdit")) then
        .edits[$t.id] = {path: ($t.input.file_path // $t.input.notebook_path), write: ($t.name == "Write"), lines: size($t)} | .verify = null
      elif $t.name == "Bash" and (($t.input.command // "") | test($v)) then .verify = {id: $t.id, ok: null}
      else . end)
  elif $r.type == "user" then
    reduce ($r.message.content[]? | select(type == "object" and .type == "tool_result")) as $x (.;
      (if $x.is_error == true then del(.edits[$x.tool_use_id]) else . end)
      | (if .verify.id == $x.tool_use_id then .verify.ok = ($x.is_error != true) else . end))
  else . end)
| . as $s
| [$s.edits[] | select((.path | type) == "string" and (.path | startswith($cwd + "/"))) | .path |= .[($cwd | length + 1):]] as $e
| {files: ($e | map(.path) | unique),
   writes: ($e | map(select(.write and (.path | (doc or inert) | not)) | .path) | unique),
   prod: ($e | map(select(.path | (doc or inert) | not) | .lines) | add // 0),
   docsOnly: ($e | all(.path | doc)),
   verify: $s.verify}
JQ
TURN="$(jq -cn --arg v "$VERIFY" --arg cwd "$CWD" "$TURN_JQ" "$TRANSCRIPT" 2>/dev/null)" || exit 0
NFILES="$(jq '.files | length' <<<"$TURN")"
(( NFILES > 0 )) || exit 0
NNEW="$(jq '.writes | length' <<<"$TURN")"
PROD="$(jq '.prod' <<<"$TURN")"
STATE="$(jq -r 'if .docsOnly then "docs" elif .verify == null then "none" elif .verify.ok == false then "red" else "ok" end' <<<"$TURN")"

unwired() {
  local rel stem re="$UNWIRED_SKIP"
  git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  while IFS= read -r rel; do
    [[ "$rel" =~ \.(tsx?|jsx?|mjs|cjs|py|vue|svelte)$ && ! "$rel" =~ $re ]] || continue
    stem="${rel##*/}"; stem="${stem%.*}"
    git -C "$CWD" grep -qIF --untracked -e "$stem" -- . ":(exclude,literal)$rel" || printf '%s\n' "$rel"
  done < <(jq -r '.writes[]' <<<"$TURN")
}

todo=()
[[ "$STATE" == none ]] && todo+=("no verification ran after the last edit: run the repo's verify command and cite command + exit")
[[ "$STATE" == red ]] && todo+=("the last verification failed: fix it, or report the failure instead of calling this done")
if (( NFILES > MAX_FILES || NNEW > MAX_NEW_FILES || PROD > MAX_PROD_LINES )); then
  todo+=("footprint is $NFILES files, $NNEW new, $PROD production lines (budget $MAX_FILES/$MAX_NEW_FILES/$MAX_PROD_LINES): say which part of the ask each extra hunk serves and revert what none does")
fi
UNWIRED="$(unwired | paste -sd ' ' -)"
[[ -z "$UNWIRED" ]] || todo+=("nothing references the new file(s) $UNWIRED: import or register them, or delete them")

LOG="$HOME/.claude/state/bridle-turns.jsonl"
if mkdir -p "${LOG%/*}" 2>/dev/null; then
  jq -c --arg ts "$(date -u +%FT%TZ)" --arg s "$SESSION" --arg c "$CWD" --arg st "$STATE" \
    '. + {ts: $ts, session: $s, cwd: $c, verified: $st, blocked: ($ARGS.positional | length > 0), findings: $ARGS.positional}' \
    --args ${todo[@]+"${todo[@]}"} <<<"$TURN" >>"$LOG" 2>/dev/null || true
fi

(( ${#todo[@]} > 0 )) || exit 0
{
  echo "bridle: turn-check: not done yet."
  printf ' - %s\n' "${todo[@]}"
  git -C "$CWD" diff --stat 2>/dev/null | head -n 12
  echo "If the ask required all of this, say so in one line and finish."
} >&2
exit 2
