#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/metrics.sh"
source "$HERE/lib/shared_state.sh"
POLICY="$HERE/policy/lean.json"
MAX="$(jq -r '.file_loc_max // 700' "$POLICY" 2>/dev/null || echo 700)"
CC_MAX="$(jq -r '.complexity_max // 50' "$POLICY" 2>/dev/null || echo 50)"
CC_FUNC="$(jq -r '.func_complexity_max // 15' "$POLICY" 2>/dev/null || echo 15)"
COUPLE_MAX="$(jq -r '.coupling_max // 10' "$POLICY" 2>/dev/null || echo 10)"
NEST_MAX="$(jq -r '.nesting_max // 4' "$POLICY" 2>/dev/null || echo 4)"
VMAX="$(jq -r '.edit_velocity_max // 15' "$POLICY" 2>/dev/null || echo 15)"
COMMENT_MAX="$(jq -r '.comment_ratio_max // 25' "$POLICY" 2>/dev/null || echo 25)"
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')"
resolve_root
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
VELOCITY_LOG="$STATE/edit_velocity.log"

# Cursor primary: Write. Claude-compat: Edit|MultiEdit|StrReplace.
case "$TOOL_NAME" in
  Write|Edit|MultiEdit|StrReplace) ;;
  *) emit_allow; exit 0 ;;
esac
[[ -z "$FILE_PATH" ]] && { emit_allow; exit 0; }

count_lines() { [[ -z "$1" ]] && { echo 0; return; }; printf '%s\n' "$1" | wc -l; }

REDUCE=0
if [[ "$TOOL_NAME" == "Write" ]]; then
  CONTENT="$(printf '%s' "$INPUT" | jq -r '(.tool_input.content // empty) | if type=="array" then map((.text // .content // "")) | join("\n") else . end' 2>/dev/null || true)"
  LINES="$(count_lines "$CONTENT")"
  LINES="${LINES//[!0-9]}"
  [[ -z "$LINES" ]] && LINES=0
  [[ "${LINES:-0}" -gt "$MAX" ]] && { emit_deny "MECHANICAL DENY: Write ${LINES} LOC > ${MAX} roof. Split into smaller modules."; exit 0; }
else
  [[ -f "$FILE_PATH" ]] || { emit_allow; exit 0; }
  CUR="$(wc -l < "$FILE_PATH")"
  CUR="${CUR//[!0-9]}"; [[ -z "$CUR" ]] && CUR=0
  if [[ "$TOOL_NAME" == "MultiEdit" ]]; then
    OLD_C="$(printf '%s' "$INPUT" | jq -r '[.tool_input.edits[]?.old_string // ""] | join("\n")' | wc -l)"
    NEW_CONTENT="$(printf '%s' "$INPUT" | jq -r '[.tool_input.edits[]?.new_string // ""] | join("\n")' 2>/dev/null || true)"
  else
    OLD_C="$(printf '%s' "$INPUT" | jq -r '.tool_input.old_string // ""' | wc -l)"
    NEW_CONTENT="$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)"
  fi
  OLD_C="${OLD_C//[!0-9]}"; [[ -z "$OLD_C" ]] && OLD_C=0
  NEW_C="$(count_lines "$NEW_CONTENT")"
  NEW_C="${NEW_C//[!0-9]}"; [[ -z "$NEW_C" ]] && NEW_C=0
  PROJECTED=$(( CUR - OLD_C + NEW_C ))
  [[ "$PROJECTED" -gt "$MAX" ]] && { emit_deny "MECHANICAL DENY: projected ${PROJECTED} LOC > ${MAX} roof (current ${CUR}). Split."; exit 0; }
  [[ "$PROJECTED" -lt "$CUR" ]] && REDUCE=1
  CONTENT="$NEW_CONTENT"
fi

velocity_bump "$FILE_PATH" "$REDUCE"

if is_executable_src "$FILE_PATH"; then
  comment_ratio_check "$CONTENT" "$COMMENT_MAX" || { log_session_event "DENY" "lean_gate: comments $FILE_PATH"; exit 0; }
fi
coupling_check "$CONTENT" "$COUPLE_MAX" || { log_session_event "DENY" "lean_gate: coupling $FILE_PATH"; exit 0; }
nesting_check "$CONTENT" "$NEST_MAX" || { log_session_event "DENY" "lean_gate: nesting $FILE_PATH"; exit 0; }
complexity_check "$CONTENT" "$CC_MAX" "$CC_FUNC" || { log_session_event "DENY" "lean_gate: complexity $FILE_PATH"; exit 0; }
log_session_event "ALLOW" "lean_gate: $FILE_PATH"
emit_allow; exit 0
