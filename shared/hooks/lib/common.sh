#!/usr/bin/env bash

resolve_root() {
  local d
  # Hooks spawn with cwd = workspace root (proven by relative repo-level
  # commands); prefer it so the global ~/.cursor layer keeps per-project
  # HANDOFF/state. Fall back to walking up from the script location.
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

# Cursor deny/allow schema: permission + optional user_message / agent_message.
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

emit_followup() {
  local msg="$1"
  jq -n --arg m "$msg" '{followup_message: $m}'
}

emit_quiet() { echo '{}'; }

# sessionStart (and postToolUse) context injection — snake_case per Cursor docs.
emit_context() {
  local ctx="$1"
  jq -n --arg c "$ctx" '{additional_context: $c}'
}

# beforeSubmitPrompt is block/allow only — not a context injection point.
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
  case "$1" in
    *.sh|*.bash|*.zsh|*.py|*.rb|*.pl|*.js|*.mjs|*.cjs|*.ts|*.tsx|*.go|*.rs|*.c|*.cpp|*.cc|*.h|*.hpp|*.java|*.kt|*.swift|*.scala|*.php|*.lua|*.r|*.jl|*.ex|*.exs) return 0 ;;
    *) return 1 ;;
  esac
}

if stat -f %m / >/dev/null 2>&1; then
  file_mtime() { stat -f %m "$1" 2>/dev/null; }
else
  file_mtime() { stat -c %Y "$1" 2>/dev/null; }
fi

# flock(1) is util-linux only; mkdir is the portable atomic lock primitive.
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
    sleep 0.05
  done
  _LOCK_DIR="$lockdir"
}

release_lock() {
  [[ -n "$_LOCK_DIR" ]] && rmdir "$_LOCK_DIR" 2>/dev/null || true
}
