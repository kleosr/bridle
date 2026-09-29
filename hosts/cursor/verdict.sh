#!/usr/bin/env bash
# Cursor verdicts: {"permission": allow|deny|ask} for shell and read,
# {"continue": bool} for beforeSubmitPrompt.

json_emit() {
  local kind="$1"
  KLEOS_JSON_MSG="${2:-}" KLEOS_JSON_REASON="${3:-}" KLEOS_JSON_AGENT="${4:-}" \
    KLEOS_JSON_CONTINUE="${5:-}" \
    json_run emit "$kind"
}

emit_perm() {
  local kind="$1" msg="$2" reason="$3" agent="${4:-}"
  json_emit "$kind" "$msg" "$reason" "$agent" && return 0
  echo "{\"permission\":\"$kind\",\"user_message\":\"kleosrules: JSON tool required\",\"reason\":\"missing-json\"}"
}

# A bare allow is a constant; spawning the codec to print it cost one
# interpreter start per allowed Read/Shell on the native hot path.
emit_allow() {
  if [[ -z "${1:-}" ]]; then
    echo '{"permission":"allow"}'
    return 0
  fi
  json_emit allow "$1" && return 0
  echo '{"permission":"allow"}'
}

emit_deny() {
  emit_perm deny "$1" "${3:-deny}" "$2"
}

emit_ask() {
  emit_perm ask "$1" "${3:-ask}" "$2"
}

emit_continue() {
  local cont="${1:-true}" msg="${2:-}" reason="${3:-}"
  if [[ "$cont" == "false" ]]; then
    json_emit continue "$msg" "${reason:-block}" "" false && return 0
    printf '%s\n' "{\"continue\":false,\"reason\":\"${reason:-block}\"}"
    return 0
  fi
  json_emit continue "$msg" && return 0
  echo '{"continue":true}'
}

host_skip() { return 1; }
