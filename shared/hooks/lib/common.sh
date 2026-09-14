#!/usr/bin/env bash
# Shared hook helpers: JSON codec, path canonicalization, verdict emitters.
# stdout is JSON only. Deny/ask messages never echo the command or secrets.

KLEOS_HOOK_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=json.sh
source "$KLEOS_HOOK_LIB/json.sh"

# jq remains for install/scripts (feature.sh, doctor, hooks.json merge).
# Event hooks must not call it.
jq_executable() {
  if [[ -n "${KLEOS_JQ_BIN:-}" ]]; then
    [[ -x "$KLEOS_JQ_BIN" ]] && printf '%s\n' "$KLEOS_JQ_BIN"
    return 0
  fi
  type -P jq 2>/dev/null || true
}

jq_available() { [[ -n "$(jq_executable)" ]]; }

require_jq() {
  if ! jq_available; then
    echo "jq is required but was not found on PATH" >&2
    echo "fix: install jq (or set KLEOS_JQ_BIN), then run bash scripts/doctor.sh" >&2
    exit 1
  fi
}

if ! declare -F jq >/dev/null 2>&1; then
  KLEOS_JQ_EXEC="$(jq_executable)"
  if [[ -n "$KLEOS_JQ_EXEC" ]]; then
    jq() { "$KLEOS_JQ_EXEC" "$@" | tr -d '\r'; }
  fi
fi

hook_stdin() {
  local s
  s="$(cat)"
  s="${s#$'\xEF\xBB\xBF'}"
  printf '%s' "$s" | tr -d '\r'
}

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

json_emit() {
  local kind="$1"
  KLEOS_JSON_MSG="${2:-}" KLEOS_JSON_REASON="${3:-}" KLEOS_JSON_AGENT="${4:-}" \
    KLEOS_JSON_CONTINUE="${5:-}" KLEOS_JSON_PERM="${6:-}" \
    json_run emit "$kind"
}

emit_allow() {
  json_emit allow "${1:-}" && return 0
  echo '{"permission":"allow"}'
}

emit_deny() {
  local msg="$1" agent="${2:-}" reason="${3:-deny}"
  if type detect_host >/dev/null 2>&1 && [[ "$(detect_host)" == "claude" ]]; then
    json_emit claude "$msg" "$reason" "" "" deny && return 0
  fi
  json_emit deny "$msg" "$reason" "$agent" && return 0
  echo '{"permission":"deny","user_message":"kleosrules: JSON tool required","reason":"missing-json"}'
}

emit_ask() {
  local msg="$1" agent="${2:-}" reason="${3:-ask}"
  if type detect_host >/dev/null 2>&1 && [[ "$(detect_host)" == "claude" ]]; then
    json_emit claude "$msg" "$reason" "" "" ask && return 0
  fi
  json_emit ask "$msg" "$reason" "$agent" && return 0
  echo '{"permission":"ask","user_message":"kleosrules: JSON tool required","reason":"missing-json"}'
}

emit_quiet() { echo '{}'; }

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

emit_followup() {
  json_emit followup "$1" && return 0
  echo '{}'
}
