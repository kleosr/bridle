#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/metrics.sh"
source "$HERE/lib/shared_state.sh"
POLICY="$HERE/policy/lean.json"
MAX="$(jq -r '.file_loc_max // 700' "$POLICY" 2>/dev/null || echo 700)"
SOFT="$(jq -r '.file_loc_soft // 150' "$POLICY" 2>/dev/null || echo 150)"
CC_MAX="$(jq -r '.complexity_max // 50' "$POLICY" 2>/dev/null || echo 50)"
CC_FUNC="$(jq -r '.func_complexity_max // 15' "$POLICY" 2>/dev/null || echo 15)"
COUPLE_MAX="$(jq -r '.coupling_max // 10' "$POLICY" 2>/dev/null || echo 10)"
NEST_MAX="$(jq -r '.nesting_max // 4' "$POLICY" 2>/dev/null || echo 4)"
VMAX="$(jq -r '.edit_velocity_max // 15' "$POLICY" 2>/dev/null || echo 15)"
COMMENT_MAX="$(jq -r '.comment_ratio_max // 2' "$POLICY" 2>/dev/null || echo 2)"
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty')"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')"
resolve_root
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
VELOCITY_LOG="$STATE/edit_velocity.log"

case "$TOOL_NAME" in
  Write|Edit|MultiEdit|StrReplace) ;;
  *) emit_allow; exit 0 ;;
esac
[[ -z "$FILE_PATH" ]] && { emit_allow; exit 0; }
# Edit aliases need an on-disk file to project; Write creates/overwrites.
if [[ "$TOOL_NAME" != "Write" && ! -f "$FILE_PATH" ]]; then
  emit_allow; exit 0
fi

count_lines() { [[ -z "$1" ]] && { echo 0; return; }; printf '%s\n' "$1" | wc -l; }

CONTENT="$(project_edit_content "$TOOL_NAME" "$FILE_PATH" "$INPUT")"
LINES="$(count_lines "$CONTENT")"
LINES="${LINES//[!0-9]}"; [[ -z "$LINES" ]] && LINES=0
CUR=0
[[ -f "$FILE_PATH" ]] && CUR="$(wc -l < "$FILE_PATH")"
CUR="${CUR//[!0-9]}"; [[ -z "$CUR" ]] && CUR=0
REDUCE=0
[[ "$LINES" -lt "$CUR" ]] && REDUCE=1
[[ "$LINES" -gt "$MAX" ]] && { emit_deny "MECHANICAL DENY: projected ${LINES} LOC > ${MAX} roof. Split into smaller modules."; exit 0; }

velocity_bump "$FILE_PATH" "$REDUCE"

if is_executable_src "$FILE_PATH"; then
  comment_ratio_check "$CONTENT" "$COMMENT_MAX" || { log_session_event "DENY" "lean_gate: comments $FILE_PATH"; exit 0; }
fi
coupling_check "$CONTENT" "$COUPLE_MAX" || { log_session_event "DENY" "lean_gate: coupling $FILE_PATH"; exit 0; }
nesting_check "$CONTENT" "$NEST_MAX" || { log_session_event "DENY" "lean_gate: nesting $FILE_PATH"; exit 0; }
complexity_check "$CONTENT" "$CC_MAX" "$CC_FUNC" || { log_session_event "DENY" "lean_gate: complexity $FILE_PATH"; exit 0; }

SOFT_MSG=""
if is_executable_src "$FILE_PATH" && [[ "$LINES" -gt "$SOFT" ]]; then
  SOFT_MSG="SOFT LOC: projected ${LINES} LOC > soft roof ${SOFT} (hard ${MAX}). Prefer extract/split before growing further."
  log_session_event "WARN" "lean_gate soft LOC $FILE_PATH lines=$LINES"
fi
log_session_event "ALLOW" "lean_gate: $FILE_PATH"
if [[ -n "$SOFT_MSG" ]]; then emit_allow "$SOFT_MSG"; else emit_allow; fi
exit 0
