#!/usr/bin/env bash
set -euo pipefail
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$HERE/lib/common.sh"
source "$HERE/lib/shell_gate.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
ALLOWED="$STATE/allowed_files.md"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // .name // empty')"
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
is_executable_path() {
  case "$1" in
    *.sh|*.bash|*.zsh|*.py|*.rb|*.pl|*.js|*.mjs|*.cjs|*.ts|*.go|*.rs|*.c|*.cpp|*.cc|*.h|*.hpp|*.java|*.kt|*.swift|*.scala|*.php|*.lua|*.r|*.jl|*.ex|*.exs|*.ps1|*.bat|*.cmd|*.psm1) return 0 ;;
    *) return 1 ;;
  esac
}
case "$TOOL_NAME" in
  Read|Grep|Glob|LS|Delete|BashOutput|WebFetch|WebSearch|TodoWrite|Task|TaskOutput) emit_quiet; exit 0 ;;
esac
# Cursor primary: Write. Claude-compat aliases: Edit|MultiEdit|StrReplace.
case "$TOOL_NAME" in
  Write|Edit|MultiEdit|StrReplace)
    FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')"
    [[ -z "$FILE_PATH" ]] && { emit_quiet; exit 0; }
    printf '%s\n' "$FILE_PATH" >>"$STATE/writes" 2>/dev/null || true
    if [[ -s "$ALLOWED" ]]; then
      base="$(basename "$FILE_PATH")"
      if ! grep -qxF "$FILE_PATH" "$ALLOWED" 2>/dev/null && ! grep -qxF "$base" "$ALLOWED" 2>/dev/null; then
        mkdir -p "$STATE"
        grep -qxF "$FILE_PATH" "$ALLOWED" 2>/dev/null || echo "$FILE_PATH" >>"$ALLOWED"
        warn_allow "SCOPE EXPANSION: '$FILE_PATH' is outside your declared FILE_MAP — registered in the sandbox. Declare it in your INTENT (edit:$FILE_PATH) so stop_gate audits completion. Proceeding."
      fi
    fi
    NEW_CONTENT=""
    case "$TOOL_NAME" in
      Write) NEW_CONTENT="$(echo "$INPUT" | jq -r '(.tool_input.content // empty) | if type=="array" then map((.text // .content // "")) | join("\n") else . end' 2>/dev/null || true)" ;;
      Edit|MultiEdit) NEW_CONTENT="$(echo "$INPUT" | jq -r '[.tool_input.new_string // "", (.tool_input.edits[]?.new_string // "")] | join("\n")' 2>/dev/null || true)" ;;
      StrReplace) NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)" ;;
    esac
    if is_executable_path "$FILE_PATH"; then
      DESTRUCTIVE_RE='(DROP TABLE|DELETE FROM .* WHERE 1=1|rm -rf /|password[[:space:]]*=[[:space:]]*["'"'"'"][^"'"'"'"]+["'"'"'"]|API_KEY[[:space:]]*=[[:space:]]*["'"'"'"][^"'"'"'"]+["'"'"'"]|secret[[:space:]]*=[[:space:]]*["'"'"'"][^"'"'"'"]+["'"'"'"])'
      if echo "$NEW_CONTENT" | grep -qiE "$DESTRUCTIVE_RE"; then
        deny "AUTONOMY BLOCK: executable file edit contains a destructive/credential pattern (drop/delete-all/secret write). Human approval required."
      fi
    fi
    emit_quiet; exit 0
    ;;
esac
# Cursor primary: Shell. Claude-compat alias: Bash.
case "$TOOL_NAME" in
  Shell|Bash|shell|bash)
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
