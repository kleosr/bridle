#!/usr/bin/env bash
set -euo pipefail
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$HERE/lib/common.sh"
source "$HERE/lib/shell_gate.sh"
source "$HERE/lib/tool_io.sh"
source "$HERE/lib/shared_state.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
ALLOWED="$STATE/allowed_files.md"
TOOL_NAME="$(extract_tool_name "$INPUT")"
FILE_PATH="$(extract_file_path "$INPUT")"
deny() {
  local msg="$1"
  emit_deny "$msg"
  exit 0
}
warn_allow() {
  local msg="$1"
  emit_allow "$msg"
  exit 0
}
path_was_read() {
  local fp="$1" base
  [[ -z "$fp" || ! -f "${STATE}/reads" ]] && return 1
  grep -qF "$fp" "${STATE}/reads" 2>/dev/null && return 0
  base="$(basename "$fp")"
  grep -qF "$base" "${STATE}/reads" 2>/dev/null && return 0
  return 1
}

session_searched() {
  [[ -f "${STATE}/session.log" ]] && grep -qE 'GREP|GLOB' "${STATE}/session.log" 2>/dev/null
}

write_is_grounded() {
  local fp="$1" disk
  [[ -z "$fp" ]] && return 1
  path_was_read "$fp" && return 0
  disk="$fp"
  [[ "$fp" != /* && -n "${ROOT:-}" ]] && disk="${ROOT}/${fp}"
  if [[ ! -e "$disk" ]]; then
    session_searched && return 0
  fi
  return 1
}

require_grounding() {
  local fp="$1"
  is_agent_mode || return 0
  write_is_grounded "$fp" && return 0
  deny "GROUNDING: Grep/Glob this codebase, then Read '$fp' before Write/StrReplace/Delete. Do not invent paths. Then declare INTENT + OBJECTIVE + edit:|NEW: from hits."
}

sandbox_nudge() {
  local fp="$1" base nudge=""
  [[ -z "$fp" ]] && return 0
  stamp_write "$fp"
  mkdir -p "$STATE"
  base="$(basename "$fp")"
  if [[ ! -s "$ALLOWED" ]]; then
    echo "$fp" >>"$ALLOWED"
    nudge="FILE_MAP nudge: write '$fp' with no edit:|NEW: tags in INTENT yet — registered in sandbox. Declare edit:$fp (or NEW:) in chat INTENT. Proceeding."
  elif ! grep -qxF "$fp" "$ALLOWED" 2>/dev/null && ! grep -qxF "$base" "$ALLOWED" 2>/dev/null; then
    echo "$fp" >>"$ALLOWED"
    nudge="SCOPE EXPANSION: '$fp' is outside your declared FILE_MAP — registered in the sandbox. Declare it in your INTENT (edit:$fp) so stop_gate audits completion. Proceeding."
  fi
  printf '%s' "$nudge"
}
case "$(tool_family "$TOOL_NAME")" in
  read)
    mkdir -p "$STATE"
    case "$TOOL_NAME" in
      Grep)
        PAT="$(echo "$INPUT" | jq -r '.tool_input.pattern // .tool_input.query // empty' 2>/dev/null || true)"
        log_session_event "GREP" "${PAT:0:80}"
        printf 'Grep\n' >>"$STATE/reads" 2>/dev/null || true
        ;;
      Glob)
        PAT="$(echo "$INPUT" | jq -r '.tool_input.glob_pattern // .tool_input.pattern // empty' 2>/dev/null || true)"
        log_session_event "GLOB" "${PAT:0:80}"
        ;;
      Read)
        [[ -n "$FILE_PATH" ]] && printf '%s\n' "$FILE_PATH" >>"$STATE/reads" 2>/dev/null || true
        log_session_event "READ" "${FILE_PATH:0:120}"
        ;;
    esac
    emit_quiet; exit 0
    ;;
  write)
    [[ -z "$FILE_PATH" ]] && { emit_quiet; exit 0; }
    require_grounding "$FILE_PATH"
    NUDGE="$(sandbox_nudge "$FILE_PATH")"
    NEW_CONTENT=""
    case "$TOOL_NAME" in
      Write) NEW_CONTENT="$(echo "$INPUT" | jq -r '(.tool_input.content // empty) | if type=="array" then map((.text // .content // "")) | join("\n") else . end' 2>/dev/null || true)" ;;
      StrReplace|EditNotebook) NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)" ;;
    esac
    if is_script_path "$FILE_PATH"; then
      DESTRUCTIVE_RE='(DROP TABLE|DELETE FROM .* WHERE 1=1|rm -rf /|password[[:space:]]*=[[:space:]]*["'"'"'"][^"'"'"'"]+["'"'"'"]|API_KEY[[:space:]]*=[[:space:]]*["'"'"'"][^"'"'"'"]+["'"'"'"]|secret[[:space:]]*=[[:space:]]*["'"'"'"][^"'"'"'"]+["'"'"'"])'
      if echo "$NEW_CONTENT" | grep -qiE "$DESTRUCTIVE_RE"; then
        deny "AUTONOMY BLOCK: executable file edit contains a destructive/credential pattern (drop/delete-all/secret write). Human approval required."
      fi
    fi
    if [[ -n "$NUDGE" ]]; then warn_allow "$NUDGE"; fi
    emit_quiet; exit 0
    ;;
  delete)
    [[ -z "$FILE_PATH" ]] && { emit_quiet; exit 0; }
    require_grounding "$FILE_PATH"
    NUDGE="$(sandbox_nudge "$FILE_PATH")"
    if [[ -n "$NUDGE" ]]; then warn_allow "$NUDGE"; fi
    emit_quiet; exit 0
    ;;
  shell)
    CMD="$(echo "$INPUT" | jq -r '.tool_input.command // .tool_input.cmd // .command // empty')"
    [[ -z "$CMD" ]] && { emit_quiet; exit 0; }
    if ! gate_shell_command "$CMD"; then
      exit 0
    fi
    emit_quiet; exit 0
    ;;
esac
emit_quiet
exit 0
