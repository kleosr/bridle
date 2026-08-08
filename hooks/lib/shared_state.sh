#!/usr/bin/env bash

log_session_event() {
  local event="$1" details="$2"
  local dir="${STATE:-}"
  [[ -z "$dir" ]] && dir="$(state_dir 2>/dev/null || echo /tmp)"
  mkdir -p "$dir" 2>/dev/null || return 0
  printf '%s | %s | %s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "$event" "$details" >>"$dir/session.log" 2>/dev/null || true
}

velocity_bump() {
  local fp="$1" skip="${2:-0}" vmax="${VMAX:-15}" log="${VELOCITY_LOG:-}"
  [[ -z "$log" ]] && return 0
  mkdir -p "$(dirname "$log")"
  acquire_lock
  local count
  count="$(grep -cxF "$fp" "$log" 2>/dev/null || echo 0)"
  count="${count//[!0-9]}"; [[ -z "$count" ]] && count=0
  echo "$fp" >>"$log"
  release_lock
  [[ "$skip" -eq 1 ]] && return 0
  if [[ "$count" -ge "$vmax" ]]; then
    jq -n --arg m "VELOCITY DENY: '${fp##*/}' edited ${count}x this session (roof ${vmax}). Extract a module or refactor before retrying." '{action:"deny",user_message:$m}'
    exit 0
  fi
}
