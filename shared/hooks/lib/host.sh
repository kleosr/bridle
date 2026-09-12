#!/usr/bin/env bash
# Host I/O adapter. Gate logic is host-agnostic; this file only maps payload
# fields and verdict JSON. Default: Cursor. Set KLEOS_HOST=claude for Claude Code.

detect_host() {
  if [[ -n "${KLEOS_HOST:-}" ]]; then
    printf '%s' "$KLEOS_HOST"
    return
  fi
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    printf '%s' "claude"
    return
  fi
  printf '%s' "cursor"
}

# Permission verdict. Cursor: {permission}. Claude Code PreToolUse:
# hookSpecificOutput.permissionDecision. Unknown hosts get the Cursor shape.
emit_host_permission() {
  local perm="$1" msg="${2:-}" reason="${3:-}" host
  host="$(detect_host)"
  case "$host" in
    claude)
      jq -n --arg d "$perm" --arg r "$msg" --arg why "$reason" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r},reason:$why}'
      ;;
    *)
      case "$perm" in
        deny) emit_deny "$msg" "" "$reason" ;;
        ask) emit_ask "$msg" "" "$reason" ;;
        *) emit_allow "$msg" ;;
      esac
      ;;
  esac
}
