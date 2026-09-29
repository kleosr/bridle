#!/usr/bin/env bash
# Claude Code PreToolUse(Write): enforce core.md mechanically inside the
# session's project. Exit 2 blocks the tool and feeds stderr back to the model;
# any other non-zero exit fails open in Claude Code, so every failure path
# ends in exit 2 (failClosed).
set -uo pipefail
MAX_NEW_LINES=300

deny() { printf 'bridle: %s: %s\n' "$1" "$2" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || deny missing-json "jq is unavailable; Write denied. Install jq."
INPUT="$(cat)"
FIELDS="$(printf '%s' "$INPUT" | jq -r '
  (.cwd // .workspace_roots[0] // ""),
  (.tool_input.file_path // .tool_input.path // ""),
  (.tool_input.content // "" | rtrimstr("\n") | split("\n") | length),
  (.cursor_version // "")' 2>/dev/null)" \
  || deny malformed "PreToolUse payload is not JSON; Write denied."
{ read -r CWD; read -r FILE; read -r LINES; read -r HOST; } <<<"$FIELDS"
[[ -n "$CWD" && -n "$FILE" ]] || deny malformed "payload lacks a project root or tool_input.file_path; Write denied."
[[ "$FILE" == /* ]] || FILE="$CWD/$FILE"

# Scratchpads, memory, and plans live outside the project and are not code.
[[ "$FILE" == "$CWD"/* ]] || exit 0

if [[ -e "$FILE" ]]; then
  # Cursor 3.21 runs this Claude hook. Its Write carries the whole file and
  # workspace_roots, and that call is the edit.
  [[ -n "$HOST" ]] && exit 0
  deny rewrite-existing "$FILE exists; change it with Edit, not a whole-file Write."
fi

# Size caps exclude generated, vendor, lockfiles, migrations, and declarative config.
case "$FILE" in
  */node_modules/*|*/vendor/*|*/migrations/*|*/generated/*) exit 0 ;;
  *.json|*.jsonc|*.lock|*.yaml|*.yml|*.toml|*.md|*.mdx|*.txt|*.csv|*.svg) exit 0 ;;
esac
if (( LINES > MAX_NEW_LINES )); then
  deny new-file-over-300 "$FILE would be $LINES lines; new hand-written files cap at $MAX_NEW_LINES. Split by job."
fi
exit 0
