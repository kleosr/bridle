#!/usr/bin/env bash
# hooks/lib/common.sh — shared utilities for all hooks.
# Sourced, not executed. Provides: ROOT resolution, state dir, deny/allow/follow helpers.
# Each consumer sets HERE before sourcing: HERE="$(cd "$(dirname "$0")" && pwd)"

resolve_root() {
  local d
  for d in "$HERE/.." "$HERE/../.." "$HERE/../../.."; do
    if [[ -f "$d/HANDOFF.md" || -f "$d/AGENTS.md" ]]; then
      ROOT="$(cd "$d" && pwd)"; return 0
    fi
  done
  ROOT="$(cd "$HERE/.." && pwd)"
}

state_dir() { printf '%s' "$ROOT/state"; }

# Emit allow JSON (for preToolUse gates).
emit_allow() { echo '{"action":"allow"}'; }

# Emit deny JSON (for preToolUse gates). Takes a message.
emit_deny() {
  local msg="$1"
  jq -n --arg m "$msg" '{action:"deny", user_message:$m}'
}

# Emit followup JSON (for stop gate). Takes a message.
emit_followup() {
  local msg="$1"
  jq -n --arg m "$msg" '{followup_message: $m}'
}

# Emit empty (pass-through, no opinion).
emit_quiet() { echo '{}'; }

# Emit additional_context (for inject hooks). Takes context string.
emit_context() {
  local ctx="$1"
  jq -n --arg c "$ctx" '{additional_context: $c}'
}
