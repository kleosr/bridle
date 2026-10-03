#!/usr/bin/env bash
# Claude Code PreToolUse(Write|Edit|MultiEdit): deny edits to the installed
# harness anywhere; enforce core.md's edit law inside the session's project. Exit 2 blocks the tool and feeds stderr back to the model;
# any other non-zero exit fails open in Claude Code, so every payload failure
# ends in exit 2 (failClosed). An unreadable transcript skips the turn checks.
set -uo pipefail
MAX_NEW_LINES=300
LEGACY_LINES=700
SPLIT="Do not stop: move one job into a new module, import it from this file, and continue the task."

deny() { printf 'bridle: %s: %s\n' "$1" "$2" >&2; exit 2; }

size_cap_exempt() {
  case "$1" in
    */node_modules/*|*/vendor/*|*/migrations/*|*/generated/*) return 0 ;;
    *.json|*.jsonc|*.lock|*.yaml|*.yml|*.toml|*.md|*.mdx|*.txt|*.csv|*.svg) return 0 ;;
  esac
  return 1
}

edit_growth_deny() {
  local file="$1" projected="$2" cur=0
  (( projected > MAX_NEW_LINES )) || return 0
  [[ -f "$file" ]] && cur=$(wc -l <"$file" | tr -d ' ')
  (( cur > LEGACY_LINES )) && return 0
  deny edit-growth "$file would be $projected lines after this edit (cap $MAX_NEW_LINES). $SPLIT"
}

command -v jq >/dev/null 2>&1 || deny missing-json "jq is unavailable; Write denied. Install jq."
INPUT="$(cat)"
FIELDS="$(printf '%s' "$INPUT" | jq -r '
  (.cwd // .workspace_roots[0] // ""),
  (.tool_input.file_path // .tool_input.path // ""),
  (.tool_input.content // "" | rtrimstr("\n") | split("\n") | length),
  (.cursor_version // ""),
  (.tool_name // "Write"),
  (.transcript_path // "")' 2>/dev/null)" \
  || deny malformed "PreToolUse payload is not JSON; Write denied."
{ read -r CWD; read -r FILE; read -r LINES; read -r HOST; read -r TOOL; read -r TRANSCRIPT; } <<<"$FIELDS"
[[ -n "$CWD" && -n "$FILE" ]] || deny malformed "payload lacks a project root or tool_input.file_path; Write denied."
[[ "$FILE" == /* ]] || FILE="$CWD/$FILE"

OC="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
case "$FILE" in
  "$HOME"/.cursor/hooks.json|"$HOME"/.cursor/hooks/*|"$HOME"/.cursor/rules/*|\
  "$HOME"/.claude/settings.json|"$HOME"/.claude/settings.local.json|"$HOME"/.claude/hooks/*|"$HOME"/.claude/rules/*|"$HOME"/.claude/agents/*|\
  "$OC"/opencode.json|"$OC"/opencode.jsonc|"$OC"/plugin/*|"$OC"/bridle/*|"$OC"/agent/*)
    deny harness "$FILE is the installed harness; change it through the pack installer." ;;
esac
[[ "$TOOL" == Write || "$TOOL" == Edit || "$TOOL" == MultiEdit ]] || exit 0

[[ "$FILE" == "$CWD"/* ]] || exit 0

NEW_FILE=0
if [[ "$TOOL" == Write && -e "$FILE" ]]; then
  [[ -n "$HOST" ]] || deny rewrite-existing "$FILE exists; change it with Edit, not a whole-file Write."
  INPUT="$(printf '%s' "$INPUT" | jq -c --rawfile old "$FILE" '
    .tool_name = "Edit"
    | .tool_input.old_string = $old
    | .tool_input.new_string = (.tool_input.content // "")
    | del(.tool_input.content)' 2>/dev/null)" \
    || deny malformed "cannot compare the Cursor Write with $FILE on disk; Write denied."
  TOOL=Edit
fi
[[ "$TOOL" == Write ]] && NEW_FILE=1

size_cap_exempt "$FILE" && exit 0

if (( NEW_FILE && LINES > MAX_NEW_LINES )); then
  deny new-file-over-300 "$FILE would be $LINES lines; new hand-written files cap at $MAX_NEW_LINES. $SPLIT"
fi

if [[ "$TOOL" == Edit || "$TOOL" == MultiEdit ]]; then
  NET="$(printf '%s' "$INPUT" | jq -r '
    [.tool_input.old_string, .tool_input.new_string]
    | map((. // "") | if . == "" then 0 else (rtrimstr("\n") | split("\n") | length) end)
    | .[1] - .[0]' 2>/dev/null)" || deny malformed "tool_input is unreadable; Write denied."
  if (( NET > 0 )) && [[ -f "$FILE" ]]; then
    CUR=$(wc -l <"$FILE" | tr -d ' ')
    edit_growth_deny "$FILE" $((CUR + NET))
  fi
fi

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.go|*.rs|*.java|*.kt|*.kts|*.swift|*.c|*.h|*.cc|*.cpp|*.hpp|*.cs|*.php|*.dart|*.scala|*.css|*.scss|*.less|*.zig|*.fs|*.fsx|*.groovy|*.sol|*.m|*.mm|*.v)
    CMT='^\s*(//|/\*|\*(\s|/|$))' ;;
  *.py|*.sh|*.bash|*.zsh|*.rb|*.pl|*.r|*.ex|*.exs|*.nim|*.cr|*.jl|*.ps1|*.gd|*.tcl) CMT='^\s*#([^!]|$)' ;;
  *.sql|*.lua|*.hs|*.elm|*.adb|*.ads) CMT='^\s*--' ;;
  *.clj|*.cljs|*.cljc|*.el|*.lisp|*.scm|*.rkt) CMT='^\s*;' ;;
  *.erl|*.hrl) CMT='^\s*%' ;;
  *.ml|*.mli) CMT='^\s*\(\*' ;;
  *.html|*.vue|*.svelte|*.astro|*.xml) CMT='^\s*(<!--|//|/\*)' ;;
  *) exit 0 ;;
esac
ADDED="$(printf '%s' "$INPUT" | jq -r --arg re "$CMT" '
  [(.tool_input.new_string // .tool_input.content // ""), (.tool_input.old_string // "")]
  | map(split("\n") | map(select(test($re))) | length) | .[0] - .[1]' 2>/dev/null)" \
  || deny malformed "tool_input is unreadable; Write denied."
if (( ADDED > 0 )); then
  deny comment-added "this $TOOL adds $ADDED comment line(s) to $FILE. Code files get no new comments: remove them and retry. If one is truly needed (a why the code cannot show), name it in your report for the user to decide."
fi

TURN_JQ="${BASH_SOURCE%/*}/bridle_turn.jq"
MERGE='reduce .[] as $x ({files: [], writes: [], prod: 0, skills: []};
    .files += ($x.files // []) | .writes += ($x.writes // []) | .prod += ($x.prod // 0) | .skills += ($x.skills // []))
  | .files |= unique | .writes |= unique | .skills |= unique'
PENDING="$(printf '%s' "$INPUT" | jq -c --arg f "$FILE" '{id: .tool_use_id, name: .tool_name, input: (.tool_input + {file_path: $f})}')"
CALL="$(jq -cn --arg v '$^' --arg cwd "$CWD" -f "$TURN_JQ" --argjson pending "$PENDING" /dev/null 2>/dev/null)" || exit 0
if [[ -n "$HOST" ]]; then
  CONV="$(printf '%s' "$INPUT" | jq -r '.conversation_id // ""' | tr -cd 'A-Za-z0-9_-')"
  [[ -n "$CONV" ]] || exit 0
  LEDGER="${XDG_STATE_HOME:-$HOME/.local/state}/bridle/cursor/$CONV.jsonl"
  PRIOR="$(cat "$LEDGER" 2>/dev/null)"
else
  [[ -f "$TRANSCRIPT" ]] || exit 0
  PRIOR="$(jq -cn --arg v '$^' --arg cwd "$CWD" -f "$TURN_JQ" --argjson pending null "$TRANSCRIPT" 2>/dev/null)" || exit 0
fi
TURN="$(printf '%s\n%s\n' "$PRIOR" "$CALL" | jq -cs "$MERGE" 2>/dev/null)" || exit 0
REL="${FILE#"$CWD"/}"
NEED=(code-architecture slop-guard)
if [[ "$REL" =~ (^|/)(tests?|__tests__|spec)/|\.(test|spec)\.[a-z]+$|(^|/)test_[^/]*\.py$|_test\.(go|py)$ ]]; then
  NEED+=(testing)
fi
for SKILL in ${NEED[@]+"${NEED[@]}"}; do
  jq -e --arg s "$SKILL" '.skills | index($s)' <<<"$TURN" >/dev/null \
    || deny skill-not-loaded "$REL needs the $SKILL skill first: invoke Skill $SKILL (Cursor: Read skills/$SKILL/SKILL.md), apply it, then retry this $TOOL."
done
if [[ -n "$HOST" ]]; then
  { mkdir -p "${LEDGER%/*}" && printf '%s\n' "$CALL" >>"$LEDGER"; } 2>/dev/null || true
fi
exit 0
