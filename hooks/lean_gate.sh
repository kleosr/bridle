#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
POLICY="$HERE/policy/lean.json"
MAX="$(jq -r '.file_loc_max // 700' "$POLICY" 2>/dev/null || echo 700)"
COMPLEXITY_MAX="$(jq -r '.complexity_max // 30' "$POLICY" 2>/dev/null || echo 30)"
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')

# Entropy check: count flow-control keywords in the content being written/edited.
# High keyword density signals a function/module doing too much — reject before
# it even hits the LOC roof. Counts: if, for, while, switch, function/def/fn.
entropy_check() {
  local content="$1" label="$2"
  local count; count="$(printf '%s' "$content" | grep -oiE '\b(if|for|while|switch|function|def |fn )\b' | wc -l || echo 0)"
  if [[ "$count" -gt "$COMPLEXITY_MAX" ]]; then
    jq -n --arg m "ENTROPY DENY: Complejidad estructural demasiado alta (${count} keywords de control de flujo > ${COMPLEXITY_MAX} roof en ${label}). Divide el nodo." \
      '{action:"deny", user_message:$m}'; exit 2
  fi
}

if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "StrReplace" ]]; then
  echo '{"action":"allow"}'; exit 0
fi
[[ -z "$FILE_PATH" ]] && { echo '{"action":"allow"}'; exit 0; }

if [[ "$TOOL_NAME" == "Write" ]]; then
  CONTENT="$(echo "$INPUT" | jq -r '(.tool_input.content // empty) | if type=="array" then map((.text // .content // "")) | join("\n") else . end' 2>/dev/null || true)"
  LINES="$(printf '%s' "$CONTENT" | wc -l || true)"
  if [[ "${LINES:-0}" -gt "$MAX" ]]; then
    jq -n --arg m "MECHANICAL DENY: Write produces ${LINES} LOC > ${MAX} roof. Split into smaller modules." \
      '{action:"deny", user_message:$m}'; exit 2
  fi
  entropy_check "$CONTENT" "Write ${FILE_PATH##*/}"
else
  [[ -f "$FILE_PATH" ]] || { echo '{"action":"allow"}'; exit 0; }
  CUR="$(wc -l < "$FILE_PATH")"
  OLD_C="$(echo "$INPUT" | jq -r '.tool_input.old_string // ""' | wc -l)"
  NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.new_string // ""')"
  NEW_C="$(printf '%s' "$NEW_CONTENT" | wc -l)"
  PROJECTED=$(( CUR - OLD_C + NEW_C ))
  if [[ "$PROJECTED" -gt "$MAX" ]]; then
    jq -n --arg m "MECHANICAL DENY: projected ${PROJECTED} LOC after edit > ${MAX} roof (current ${CUR}). Split." \
      '{action:"deny", user_message:$m}'; exit 2
  fi
  entropy_check "$NEW_CONTENT" "Edit ${FILE_PATH##*/}"
fi

echo '{"action":"allow"}'
exit 0
