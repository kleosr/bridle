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

# Claude Code uses hookSpecificOutput.permissionDecision instead of {permission}.
# detect_host is optional: host.sh may not be sourced (e.g. codec-only callers).
emit_perm() {
  local kind="$1" msg="$2" reason="$3" agent="${4:-}"
  if type detect_host >/dev/null 2>&1 && [[ "$(detect_host)" == "claude" ]]; then
    json_emit claude "$msg" "$reason" "" "" "$kind" && return 0
  fi
  json_emit "$kind" "$msg" "$reason" "$agent" && return 0
  echo "{\"permission\":\"$kind\",\"user_message\":\"kleosrules: JSON tool required\",\"reason\":\"missing-json\"}"
}

emit_allow() {
  json_emit allow "${1:-}" && return 0
  echo '{"permission":"allow"}'
}

emit_deny() {
  emit_perm deny "$1" "${3:-deny}" "$2"
}

emit_ask() {
  emit_perm ask "$1" "${3:-ask}" "$2"
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
