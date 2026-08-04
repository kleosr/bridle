#!/usr/bin/env bash
# hooks/lean_gate.sh — Ponytail roof + entropy gate + velocity check.
# PreToolUse on Write|Edit|MultiEdit|StrReplace for Cursor and Claude Code.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
POLICY="$HERE/policy/lean.json"
MAX="$(jq -r '.file_loc_max // 700' "$POLICY" 2>/dev/null || echo 700)"
COMPLEXITY_MAX="$(jq -r '.complexity_max // 30' "$POLICY" 2>/dev/null || echo 30)"
VELOCITY_MAX="$(jq -r '.edit_velocity_max // 15' "$POLICY" 2>/dev/null || echo 15)"
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')"
resolve_root
STATE="$(state_dir)"
VELOCITY_LOG="$STATE/edit_velocity.log"

# Velocity: count edits to same file this session — too many = bloated patching.
velocity_bump() {
  local fp="$1"
  mkdir -p "$STATE"
  local count
  count="$(grep -cxF "$fp" "$VELOCITY_LOG" 2>/dev/null || echo 0)"
  count="${count//[!0-9]}"
  [[ -z "$count" ]] && count=0
  echo "$fp" >>"$VELOCITY_LOG"
  if [[ "$count" -ge "$VELOCITY_MAX" ]]; then
    jq -n --arg m "VELOCITY DENY: '${fp##*/}' edited ${count} times this session (> ${VELOCITY_MAX} roof). This file is being patched repeatedly — extract a module or refactor before retrying." \
      '{action:"deny", user_message:$m}'; exit 2
  fi
}

entropy_check() {
  local content="$1" label="$2"
  local count; count="$(printf '%s' "$content" | { grep -oiE '\b(if|for|while|switch|function|def |fn )\b' || true; } | wc -l)"
  count="${count//[!0-9]}"
  [[ -z "$count" ]] && count=0
  if [[ "$count" -gt "$COMPLEXITY_MAX" ]]; then
    jq -n --arg m "ENTROPY DENY: Complejidad estructural demasiado alta (${count} keywords de control de flujo > ${COMPLEXITY_MAX} roof en ${label}). Divide el nodo." \
      '{action:"deny", user_message:$m}'; exit 2
  fi
}

case "$TOOL_NAME" in
  Write|Edit|MultiEdit|StrReplace) ;;
  *) emit_allow; exit 0 ;;
esac
[[ -z "$FILE_PATH" ]] && { emit_allow; exit 0; }
velocity_bump "$FILE_PATH"

if [[ "$TOOL_NAME" == "Write" ]]; then
  CONTENT="$(echo "$INPUT" | jq -r '(.tool_input.content // empty) | if type=="array" then map((.text // .content // "")) | join("\n") else . end' 2>/dev/null || true)"
  LINES="$(printf '%s' "$CONTENT" | wc -l)"
  LINES="${LINES//[!0-9]}"
  [[ -z "$LINES" ]] && LINES=0
  if [[ "${LINES:-0}" -gt "$MAX" ]]; then
    jq -n --arg m "MECHANICAL DENY: Write produces ${LINES} LOC > ${MAX} roof. Split into smaller modules." \
      '{action:"deny", user_message:$m}'; exit 2
  fi
  entropy_check "$CONTENT" "Write ${FILE_PATH##*/}"
else
  [[ -f "$FILE_PATH" ]] || { emit_allow; exit 0; }
  CUR="$(wc -l < "$FILE_PATH")"
  if [[ "$TOOL_NAME" == "MultiEdit" ]]; then
    OLD_C="$(echo "$INPUT" | jq -r '[.tool_input.edits[]?.old_string // ""] | join("\n")' | wc -l)"
    NEW_CONTENT="$(echo "$INPUT" | jq -r '[.tool_input.edits[]?.new_string // ""] | join("\n")' 2>/dev/null || true)"
  else
    OLD_C="$(echo "$INPUT" | jq -r '.tool_input.old_string // ""' | wc -l)"
    NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)"
  fi
  NEW_C="$(printf '%s' "$NEW_CONTENT" | wc -l)"
  PROJECTED=$(( CUR - OLD_C + NEW_C ))
  if [[ "$PROJECTED" -gt "$MAX" ]]; then
    jq -n --arg m "MECHANICAL DENY: projected ${PROJECTED} LOC after edit > ${MAX} roof (current ${CUR}). Split." \
      '{action:"deny", user_message:$m}'; exit 2
  fi
  entropy_check "$NEW_CONTENT" "Edit ${FILE_PATH##*/}"
fi

emit_allow; exit 0
