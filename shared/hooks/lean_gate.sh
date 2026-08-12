#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/metrics.sh"
source "$HERE/lib/shared_state.sh"
source "$HERE/lib/tool_io.sh"
POLICY="$HERE/policy/lean.json"
MAX="$(jq -r '.file_loc_max // 300' "$POLICY" 2>/dev/null || echo 300)"
SOFT="$(jq -r '.file_loc_soft // 120' "$POLICY" 2>/dev/null || echo 120)"
LEGACY="$(jq -r '.file_loc_legacy_emergency // 700' "$POLICY" 2>/dev/null || echo 700)"
CC_MAX="$(jq -r '.complexity_max // 50' "$POLICY" 2>/dev/null || echo 50)"
CC_FUNC="$(jq -r '.func_complexity_max // 15' "$POLICY" 2>/dev/null || echo 15)"
COUPLE_MAX="$(jq -r '.coupling_max // 10' "$POLICY" 2>/dev/null || echo 10)"
NEST_MAX="$(jq -r '.nesting_max // 4' "$POLICY" 2>/dev/null || echo 4)"
VMAX="$(jq -r '.edit_velocity_max // 15' "$POLICY" 2>/dev/null || echo 15)"
COMMENT_MAX="$(jq -r '.comment_ratio_max // 2' "$POLICY" 2>/dev/null || echo 2)"
INPUT="$(cat)"
TOOL_NAME="$(extract_tool_name "$INPUT")"
FILE_PATH="$(extract_file_path "$INPUT")"
resolve_root
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
VELOCITY_LOG="$STATE/edit_velocity.log"
case "$TOOL_NAME" in
  Write|StrReplace) ;;
  *) emit_allow; exit 0 ;;
esac
[[ -z "$FILE_PATH" ]] && { emit_allow; exit 0; }
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
SPLIT_MSG=""
if [[ "$LINES" -gt "$MAX" ]]; then
  if [[ "$REDUCE" -eq 1 ]]; then
    if [[ "$CUR" -gt "$LEGACY" || "$LINES" -gt "$LEGACY" ]]; then
      SPLIT_MSG="EMERGENCY REWRITE IN PROGRESS: was ${CUR} LOC (legacy >${LEGACY}). Now ${LINES}, still > hard ${MAX}. Keep extracting modules; StrReplace original+callers to imports; prefer deletion."
    else
      SPLIT_MSG="SUBATOMIC SPLIT IN PROGRESS: projected ${LINES} LOC still > hard ${MAX}. Extract focused modules via Write + StrReplace original until ≤${MAX}."
    fi
  else
    if [[ "$CUR" -gt "$LEGACY" || "$LINES" -gt "$LEGACY" ]]; then
      emit_deny "EMERGENCY REWRITE: projected ${LINES} LOC (legacy monster >${LEGACY}). Stop growth. Rewrite into modules ≤${MAX} (Write new files, StrReplace original+callers to imports); prefer deletion. Hard roof ${MAX}."
    else
      emit_deny "MECHANICAL DENY: projected ${LINES} LOC > ${MAX} hard roof. Extract into subatomic modules (one job per file) — Write new files, StrReplace original. Prefer deletion over wrappers."
    fi
    exit 0
  fi
fi
velocity_bump "$FILE_PATH" "$REDUCE"
if is_executable_src "$FILE_PATH"; then
  comment_ratio_check "$CONTENT" "$COMMENT_MAX" || { log_session_event "DENY" "lean_gate: comments $FILE_PATH"; exit 0; }
fi
coupling_check "$CONTENT" "$COUPLE_MAX" || { log_session_event "DENY" "lean_gate: coupling $FILE_PATH"; exit 0; }
nesting_check "$CONTENT" "$NEST_MAX" || { log_session_event "DENY" "lean_gate: nesting $FILE_PATH"; exit 0; }
complexity_check "$CONTENT" "$CC_MAX" "$CC_FUNC" || { log_session_event "DENY" "lean_gate: complexity $FILE_PATH"; exit 0; }
SOFT_MSG="$SPLIT_MSG"
if [[ -z "$SOFT_MSG" ]] && is_executable_src "$FILE_PATH" && [[ "$LINES" -gt "$SOFT" ]]; then
  SOFT_MSG="SOFT LOC: projected ${LINES} LOC > soft ${SOFT} (hard ${MAX}). Prefer subatomic extract (one job/file) before growing further."
  log_session_event "WARN" "lean_gate soft LOC $FILE_PATH lines=$LINES"
fi
[[ -n "$SPLIT_MSG" ]] && log_session_event "WARN" "lean_gate split-progress $FILE_PATH lines=$LINES"
log_session_event "ALLOW" "lean_gate: $FILE_PATH"
if [[ -n "$SOFT_MSG" ]]; then emit_allow "$SOFT_MSG"; else emit_allow; fi
exit 0
