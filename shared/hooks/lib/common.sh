#!/usr/bin/env bash
# Shared hook helpers: path canonicalization and JSON verdict emitters.
# stdout is JSON only. Deny/ask messages never echo the command or secrets.

# Portability: some Windows jq builds emit CRLF. Hook logic compares jq
# scalars and uses them as paths, so normalize once here. JSON string values
# produced by these scripts never legitimately contain CR.
if ! declare -F jq >/dev/null 2>&1; then
  jq() { command jq "$@" | tr -d '\r'; }
fi

posix_slashes() {
  printf '%s' "${1//\\//}"
}

canon_secret_path() {
  local p n
  p="$(posix_slashes "$1")"
  p="$(printf '%s' "$p" | tr -d "'\"")"
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
  local msg="$1" agent="${2:-}" reason="${3:-deny}"
  if type detect_host >/dev/null 2>&1 && [[ "$(detect_host)" == "claude" ]]; then
    jq -n --arg m "$msg" --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$m},reason:$r}'
    return 0
  fi
  if [[ -n "$agent" ]] && jq -n --arg m "$msg" --arg a "$agent" --arg r "$reason" '{permission:"deny", user_message:$m, agent_message:$a, reason:$r}' 2>/dev/null; then
    return 0
  fi
  if jq -n --arg m "$msg" --arg r "$reason" '{permission:"deny", user_message:$m, reason:$r}' 2>/dev/null; then
    return 0
  fi
  echo '{"permission":"deny","user_message":"kleosrules: jq is required","reason":"missing-jq"}'
}

emit_ask() {
  local msg="$1" agent="${2:-}" reason="${3:-ask}"
  if type detect_host >/dev/null 2>&1 && [[ "$(detect_host)" == "claude" ]]; then
    jq -n --arg m "$msg" --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$m},reason:$r}'
    return 0
  fi
  if [[ -n "$agent" ]] && jq -n --arg m "$msg" --arg a "$agent" --arg r "$reason" '{permission:"ask", user_message:$m, agent_message:$a, reason:$r}' 2>/dev/null; then
    return 0
  fi
  if jq -n --arg m "$msg" --arg r "$reason" '{permission:"ask", user_message:$m, reason:$r}' 2>/dev/null; then
    return 0
  fi
  echo '{"permission":"ask","user_message":"kleosrules: jq is required","reason":"missing-jq"}'
}

emit_quiet() { echo '{}'; }

emit_continue() {
  local cont="${1:-true}" msg="${2:-}" reason="${3:-}"
  if [[ "$cont" == "false" ]]; then
    if [[ -n "$msg" ]] && jq -n --arg m "$msg" --arg r "${reason:-block}" '{continue:false, user_message:$m, reason:$r}' 2>/dev/null; then
      return 0
    fi
    echo '{"continue":false,"reason":"block"}'
    return 0
  fi
  if [[ -n "$msg" ]] && jq -n --arg m "$msg" '{continue:true, user_message:$m}' 2>/dev/null; then
    return 0
  fi
  echo '{"continue":true}'
}
