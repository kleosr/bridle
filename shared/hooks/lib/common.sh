#!/usr/bin/env bash

resolve_root() {
  local d
  if [[ -f "$PWD/HANDOFF.md" || -f "$PWD/AGENTS.md" ]]; then
    ROOT="$(cd "$PWD" && pwd)"; return 0
  fi
  for d in "$HERE/.." "$HERE/../.." "$HERE/../../.."; do
    if [[ -f "$d/HANDOFF.md" || -f "$d/AGENTS.md" ]]; then
      ROOT="$(cd "$d" && pwd)"; return 0
    fi
  done
  ROOT="$(cd "$HERE/.." && pwd)"
}

state_dir() {
  if [[ -n "${CONV_ID:-}" && "${CONV_ID:-}" != "default" ]]; then
    printf '%s/state/%s\n' "$ROOT" "$CONV_ID"
  else
    printf '%s/state\n' "$ROOT"
  fi
}

extract_conv_id() {
  local id
  id="$(printf '%s' "$1" | jq -r '.conversation_id // .session_id // empty' 2>/dev/null || true)"
  [[ -z "$id" || "$id" == "null" ]] && id="default"
  printf '%s' "$id"
}

emit_allow() {
  local msg="${1:-}"
  if [[ -n "$msg" ]]; then
    jq -n --arg m "$msg" '{permission:"allow", agent_message:$m}'
  else
    echo '{"permission":"allow"}'
  fi
}

emit_deny() {
  local msg="$1" agent="${2:-}"
  if [[ -n "$agent" ]]; then
    jq -n --arg m "$msg" --arg a "$agent" '{permission:"deny", user_message:$m, agent_message:$a}'
  else
    jq -n --arg m "$msg" '{permission:"deny", user_message:$m}'
  fi
}

emit_ask() {
  local msg="$1" agent="${2:-}"
  if [[ -n "$agent" ]]; then
    jq -n --arg m "$msg" --arg a "$agent" '{permission:"ask", user_message:$m, agent_message:$a}'
  else
    jq -n --arg m "$msg" '{permission:"ask", user_message:$m}'
  fi
}

emit_followup() {
  local msg="$1"
  if [[ -n "${STATE:-}" ]]; then
    mkdir -p "$STATE" 2>/dev/null || true
    printf '%s\n' "$msg" >"$STATE/followup_msg" 2>/dev/null || true
  fi
  jq -n --arg m "$msg" '{followup_message: $m}'
}

is_followup_prompt() {
  local prompt="${1:-}" fm=""
  [[ -n "${STATE:-}" && -s "$STATE/followup_msg" ]] || return 1
  fm="$(head -c 64 "$STATE/followup_msg" 2>/dev/null || true)"
  [[ -n "$fm" ]] && printf '%s' "$prompt" | grep -Fq "$fm"
}

maybe_reset_turn() {
  : >"$STATE/writes_turn"
  if is_followup_prompt "$1"; then
    return 0
  fi
  : >"$STATE/writes"
  date +%s >"$STATE/session_ts"
  rm -f "$STATE/pending_files.md" "$STATE/pending_intent.md" "$STATE/followup_msg"
}

emit_quiet() { echo '{}'; }

emit_context() {
  local ctx="$1"
  jq -n --arg c "$ctx" '{additional_context: $c}'
}

emit_continue() {
  local cont="${1:-true}" msg="${2:-}"
  if [[ "$cont" == "false" ]]; then
    if [[ -n "$msg" ]]; then
      jq -n --arg m "$msg" '{continue:false, user_message:$m}'
    else
      echo '{"continue":false}'
    fi
  else
    if [[ -n "$msg" ]]; then
      jq -n --arg m "$msg" '{continue:true, user_message:$m}'
    else
      echo '{"continue":true}'
    fi
  fi
}

is_agent_mode() {
  local mode=""
  [[ -n "${STATE:-}" && -f "$STATE/mode" ]] && mode="$(cat "$STATE/mode" 2>/dev/null || echo "")"
  [[ -z "$mode" || "$mode" == "agent" ]]
}

is_executable_src() {
  case "$1" in *.sh|*.bash|*.zsh|*.py|*.rb|*.pl|*.js|*.mjs|*.cjs|*.ts|*.tsx|*.jsx|*.go|*.rs|*.c|*.cpp|*.cc|*.h|*.hpp|*.java|*.kt|*.swift|*.scala|*.php|*.lua|*.r|*.jl|*.ex|*.exs|*.vue|*.svelte) return 0 ;; esac
  return 1
}

is_script_path() {
  is_executable_src "$1" && return 0
  case "$1" in *.ps1|*.bat|*.cmd|*.psm1) return 0 ;; esac
  return 1
}

wb_alt() {
  printf '(^|[^A-Za-z0-9_])(%s)([^A-Za-z0-9_]|$)' "$1"
}

if stat -f %m / >/dev/null 2>&1; then
  file_mtime() { stat -f %m "$1" 2>/dev/null; }
else
  file_mtime() { stat -c %Y "$1" 2>/dev/null; }
fi

_LOCK_DIR=""
acquire_lock() {
  local lockdir; lockdir="$(state_dir)/gate.lock.d"
  mkdir -p "$(state_dir)"
  local tries=0 age
  until mkdir "$lockdir" 2>/dev/null; do
    tries=$((tries + 1))
    age=$(( $(date +%s) - $(file_mtime "$lockdir" || echo 0) ))
    [[ "$age" -gt 10 ]] && { rmdir "$lockdir" 2>/dev/null || true; continue; }
    [[ "$tries" -ge 20 ]] && { emit_deny "State busy (parallel hook collision), retry."; exit 0; }
    sleep 0.05 2>/dev/null || sleep 1
  done
  _LOCK_DIR="$lockdir"
}

release_lock() {
  [[ -n "$_LOCK_DIR" ]] && rmdir "$_LOCK_DIR" 2>/dev/null || true
}
