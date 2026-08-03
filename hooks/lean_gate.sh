#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
POLICY="$HERE/policy/lean.json"
MAX="$(jq -r '.file_loc_max // 700' "$POLICY" 2>/dev/null || echo 700)"
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "StrReplace" ]]; then
  echo '{"action":"allow"}'
  exit 0
fi
if [[ -z "$FILE_PATH" ]]; then
  echo '{"action":"allow"}'
  exit 0
fi
deny() {
  jq -n --arg m "$1" '{action:"deny", user_message:$m}'
  exit 2
}
if [[ "$TOOL_NAME" == "Write" ]]; then
  LINES="$(echo "$INPUT" | jq -r '(.tool_input.content // empty) | if type=="array" then map((.text // .content // "")) | join("\n") else . end' 2>/dev/null | wc -l || true)"
  if [[ "${LINES:-0}" -gt "$MAX" ]]; then
    deny "MECHANICAL DENY: Write produces ${LINES} LOC > ${MAX} roof. Split into smaller modules."
  fi
  echo '{"action":"allow"}'
  exit 0
fi
if [[ ! -f "$FILE_PATH" ]]; then
  echo '{"action":"allow"}'
  exit 0
fi
CUR="$(wc -l < "$FILE_PATH")"
OLD_C="$(echo "$INPUT" | jq -r '.tool_input.old_string // ""' | wc -l)"
NEW_C="$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' | wc -l)"
PROJECTED=$(( CUR - OLD_C + NEW_C ))
if [[ "$PROJECTED" -gt "$MAX" ]]; then
  deny "MECHANICAL DENY: projected ${PROJECTED} LOC after edit > ${MAX} roof (current ${CUR}). Split."
fi
echo '{"action":"allow"}'
exit 0
