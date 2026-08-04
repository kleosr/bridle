#!/usr/bin/env bash
# hooks/lean_gate.sh — Ponytail roof: LOC + complexity + coupling + nesting + velocity.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/metrics.sh"
POLICY="$HERE/policy/lean.json"
MAX="$(jq -r '.file_loc_max // 700' "$POLICY" 2>/dev/null || echo 700)"
CC_MAX="$(jq -r '.complexity_max // 50' "$POLICY" 2>/dev/null || echo 50)"
CC_FUNC="$(jq -r '.func_complexity_max // 15' "$POLICY" 2>/dev/null || echo 15)"
COUPLE_MAX="$(jq -r '.coupling_max // 10' "$POLICY" 2>/dev/null || echo 10)"
NEST_MAX="$(jq -r '.nesting_max // 4' "$POLICY" 2>/dev/null || echo 4)"
VMAX="$(jq -r '.edit_velocity_max // 15' "$POLICY" 2>/dev/null || echo 15)"
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')"
resolve_root
STATE="$(state_dir)"
VELOCITY_LOG="$STATE/edit_velocity.log"

velocity_bump() {
  local fp="$1"
  mkdir -p "$STATE"
  local count
  count="$(grep -cxF "$fp" "$VELOCITY_LOG" 2>/dev/null || echo 0)"
  count="${count//[!0-9]}"
  [[ -z "$count" ]] && count=0
  acquire_lock
  echo "$fp" >>"$VELOCITY_LOG"
  release_lock
  if [[ "$count" -ge "$VMAX" ]]; then
    jq -n --arg m "VELOCITY DENY: '${fp##*/}' edited ${count}x this session (> ${VMAX} roof). Extract a module or refactor before retrying." '{action:"deny",user_message:$m}'; exit 2
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
  [[ "${LINES:-0}" -gt "$MAX" ]] && { jq -n --arg m "MECHANICAL DENY: Write ${LINES} LOC > ${MAX} roof. Split into smaller modules." '{action:"deny",user_message:$m}'; exit 2; }
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
  [[ "$PROJECTED" -gt "$MAX" ]] && { jq -n --arg m "MECHANICAL DENY: projected ${PROJECTED} LOC > ${MAX} roof (current ${CUR}). Split." '{action:"deny",user_message:$m}'; exit 2; }
  CONTENT="$NEW_CONTENT"
fi

coupling_check "$CONTENT" "$COUPLE_MAX" || exit 2
nesting_check "$CONTENT" "$NEST_MAX" || exit 2
complexity_check "$CONTENT" "$CC_MAX" "$CC_FUNC" || exit 2
emit_allow; exit 0
