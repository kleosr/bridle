#!/usr/bin/env bash
# hooks/lib/pre_tool_use_core.sh — Selective Autonomy gate logic (sourced by hooks/pre_tool_use.sh).
set -uo pipefail
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$HERE/lib/common.sh"
resolve_root
STATE="$(state_dir)"
ALLOWED="$STATE/allowed_files.md"
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // .name // empty')"
is_claude() { echo "$INPUT" | jq -e '.hook_event_name // empty' >/dev/null 2>&1; }
deny() {
  local msg="$1"
  if is_claude; then
    jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$m}}'
  else
    jq -n --arg m "$msg" '{action:"deny", user_message:$m}'
  fi
  exit 0
}
case "$TOOL_NAME" in
  Read|Grep|Glob|LS|BashOutput|WebFetch|WebSearch|TodoWrite|Task|TaskOutput) emit_quiet; exit 0 ;;
esac
case "$TOOL_NAME" in
  Write|Edit|MultiEdit|StrReplace)
    FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')"
    [[ -z "$FILE_PATH" ]] && { emit_quiet; exit 0; }
    if [[ -s "$ALLOWED" ]]; then
      base="$(basename "$FILE_PATH")"
      if ! grep -qxF "$FILE_PATH" "$ALLOWED" 2>/dev/null && ! grep -qxF "$base" "$ALLOWED" 2>/dev/null; then
        deny "TOPOLOGY BLOCK: '$FILE_PATH' is outside your declared FILE_MAP. Expand your INTENT or remove the scope restriction before editing it."
      fi
    fi
    NEW_CONTENT=""
    case "$TOOL_NAME" in
      Write) NEW_CONTENT="$(echo "$INPUT" | jq -r '(.tool_input.content // empty) | if type=="array" then map((.text // .content // "")) | join("\n") else . end' 2>/dev/null || true)" ;;
      Edit|MultiEdit) NEW_CONTENT="$(echo "$INPUT" | jq -r '[.tool_input.new_string // "", (.tool_input.edits[]?.new_string // "")] | join("\n")' 2>/dev/null || true)" ;;
      StrReplace) NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)" ;;
    esac
    DESTRUCTIVE_RE='(DROP TABLE|DELETE FROM .* WHERE 1=1|rm -rf /|password[[:space:]]*=[[:space:]]*["'"'"'"][^"'"'"']+["'"'"'"]|API_KEY[[:space:]]*=[[:space:]]*["'"'"'"][^"'"'"']+["'"'"'"]|secret[[:space:]]*=[[:space:]]*["'"'"'"][^"'"'"']+["'"'"'"])'
    if echo "$NEW_CONTENT" | grep -qiE "$DESTRUCTIVE_RE"; then
      deny "AUTONOMY BLOCK: edit contains a destructive/credential pattern (drop/delete-all/secret write). Human approval required."
    fi
    emit_quiet; exit 0
    ;;
esac
if [[ "$TOOL_NAME" == "Bash" || "$TOOL_NAME" == "bash" ]]; then
  CMD="$(echo "$INPUT" | jq -r '.tool_input.command // .tool_input.cmd // .command // empty')"
  [[ -z "$CMD" ]] && { emit_quiet; exit 0; }
  if echo "$CMD" | grep -qiE '(rm -rf? /|rm -rf? ~|mkfs|dd if=|git push --force|git push -f|drop database|truncate table|>:.*\/dev\/sd|shred )'; then
    deny "AUTONOMY BLOCK: command matches a destructive pattern. Human approval required. CMD: ${CMD:0:120}"
  fi
  if echo "$CMD" | grep -qiE '(psql|mysql|mongosh|supabase db|terraform apply|kubectl delete|docker rm -f|systemctl stop)'; then
    deny "AUTONOMY BLOCK: command mutates infra/DB. Human approval required. CMD: ${CMD:0:120}"
  fi
  emit_quiet; exit 0
fi
emit_quiet
exit 0
