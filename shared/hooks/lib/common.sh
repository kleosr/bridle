#!/usr/bin/env bash

posix_slashes() {
  printf '%s' "${1//\\//}"
}

canon_secret_path() {
  local p n
  p="$(posix_slashes "$1")"
  p="$(printf '%s' "$p" | tr -s '/')"
  p="${p//\/.\//\/}"
  n=0
  while printf '%s' "$p" | grep -qE '/[^/]+/\.\.(/|$)'; do
    p="$(printf '%s' "$p" | sed -E 's:/[^/]+/\.\.(/|$):\1:g')"
    n=$((n + 1))
    [[ "$n" -ge 16 ]] && break
  done
  printf '%s' "$p"
}

emit_allow() {
  local msg="${1:-}"
  if [[ -n "$msg" ]] && jq -n --arg m "$msg" '{permission:"allow", agent_message:$m}' 2>/dev/null; then
    return 0
  fi
  echo '{"permission":"allow"}'
}

emit_deny() {
  local msg="$1" agent="${2:-}"
  if [[ -n "$agent" ]] && jq -n --arg m "$msg" --arg a "$agent" '{permission:"deny", user_message:$m, agent_message:$a}' 2>/dev/null; then
    return 0
  fi
  if jq -n --arg m "$msg" '{permission:"deny", user_message:$m}' 2>/dev/null; then
    return 0
  fi
  echo '{"permission":"deny","user_message":"kleosrules: jq is required"}'
}

emit_ask() {
  local msg="$1" agent="${2:-}"
  if [[ -n "$agent" ]] && jq -n --arg m "$msg" --arg a "$agent" '{permission:"ask", user_message:$m, agent_message:$a}' 2>/dev/null; then
    return 0
  fi
  if jq -n --arg m "$msg" '{permission:"ask", user_message:$m}' 2>/dev/null; then
    return 0
  fi
  echo '{"permission":"ask","user_message":"kleosrules: jq is required"}'
}

emit_quiet() { echo '{}'; }

emit_continue() {
  local cont="${1:-true}" msg="${2:-}"
  if [[ "$cont" == "false" ]]; then
    if [[ -n "$msg" ]] && jq -n --arg m "$msg" '{continue:false, user_message:$m}' 2>/dev/null; then
      return 0
    fi
    echo '{"continue":false}'
    return 0
  fi
  if [[ -n "$msg" ]] && jq -n --arg m "$msg" '{continue:true, user_message:$m}' 2>/dev/null; then
    return 0
  fi
  echo '{"continue":true}'
}
