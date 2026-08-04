#!/usr/bin/env bash
# hooks/lib/shared_state.sh — lightweight cross-hook session logging.
# Append-only. No denial logic, no md5sum. Used for hook debugging only.

log_session_event() {
  local event="$1" details="$2"
  # Lazy resolve: prefer $STATE (set by consumer), fall back to state_dir(), then /tmp.
  local dir="${STATE:-}"
  [[ -z "$dir" ]] && dir="$(state_dir 2>/dev/null || echo /tmp)"
  mkdir -p "$dir" 2>/dev/null || return 0
  printf '%s | %s | %s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "$event" "$details" >>"$dir/session.log" 2>/dev/null || true
}
