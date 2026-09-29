#!/usr/bin/env bash
# Shared hook helpers: JSON codec, path canonicalization, host verdict loader.
# stdout is JSON only. Deny/ask messages never echo the command or secrets.

_src="${BASH_SOURCE[0]//\\//}"
_lib="${_src%/*}"
[[ "$_lib" == "$_src" || -z "$_lib" ]] && _lib="."
# shellcheck source=selfdir.sh
source "$_lib/selfdir.sh"
KLEOS_HOOK_LIB="$(kleos_abs_dir "$_src")"
unset _src _lib
# shellcheck source=json.sh
source "$KLEOS_HOOK_LIB/json.sh"

# jq remains for the installers (hooks.json merge, manifest lists).
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
    echo "fix: install jq (or set KLEOS_JQ_BIN)" >&2
    exit 1
  fi
}

if ! declare -F jq >/dev/null 2>&1; then
  KLEOS_JQ_EXEC="$(jq_executable)"
  if [[ -n "$KLEOS_JQ_EXEC" ]]; then
    jq() { "$KLEOS_JQ_EXEC" "$@" | tr -d '\r'; }
  fi
fi

# In-process ERE matching. Every grep/sed/tr spawn costs ~50 ms on MSYS and the
# gates run per shell segment, so hot paths use [[ =~ ]] and never fork.
# rx STR RE: case-sensitive. rxi STR RE: case-insensitive (grep -i equivalent).
rx() { [[ $1 =~ $2 ]]; }
rxi() {
  local rc=1
  shopt -s nocasematch
  if [[ $1 =~ $2 ]]; then rc=0; fi
  shopt -u nocasematch
  return "$rc"
}

# policy_match[_i] STR FILE: true when any non-empty line of FILE matches STR
# (grep -f equivalent). Lines are cached per file for the life of the process.
KLEOS_POLICY_FILE=""
KLEOS_POLICY_LINES=()
policy_load() {
  local line
  [[ "$KLEOS_POLICY_FILE" == "$1" ]] && return 0
  KLEOS_POLICY_LINES=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -n "$line" ]] && KLEOS_POLICY_LINES[${#KLEOS_POLICY_LINES[@]}]="$line"
  done <"$1"
  KLEOS_POLICY_FILE="$1"
}
policy_match() {
  local p
  policy_load "$2"
  for p in ${KLEOS_POLICY_LINES[@]+"${KLEOS_POLICY_LINES[@]}"}; do
    rx "$1" "$p" && return 0
  done
  return 1
}
policy_match_i() {
  local p
  policy_load "$2"
  for p in ${KLEOS_POLICY_LINES[@]+"${KLEOS_POLICY_LINES[@]}"}; do
    rxi "$1" "$p" && return 0
  done
  return 1
}

hook_stdin() {
  local s=""
  IFS= read -r -d '' s || true
  s="${s#$'\xEF\xBB\xBF'}"
  printf '%s' "${s//$'\r'/}"
}

posix_slashes() {
  printf '%s' "${1//\\//}"
}

canon_secret_path() {
  local p="$1" n=0 dbl='//' one='/' re='/[^/]+/\.\.(/|$)'
  p="${p//\\//}"
  p="${p//\'/}"
  p="${p//\"/}"
  while [[ "$p" == *//* ]]; do p="${p//"$dbl"/$one}"; done
  p="${p//\/.\//\/}"
  while [[ "$n" -lt 16 ]] && rx "$p" "$re"; do
    p="${p/"${BASH_REMATCH[0]}"/${BASH_REMATCH[1]}}"
    n=$((n + 1))
  done
  printf '%s' "$p"
}

# json_str STR: sets JSON_STR to STR as a quoted JSON string, no fork.
json_str() {
  local s="$1" bs='\' q='"'
  s="${s//"$bs"/$bs$bs}"
  s="${s//"$q"/$bs$q}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  JSON_STR="\"$s\""
}

# The gate decides; the host's verdict file formats. It defines emit_allow,
# emit_deny MSG AGENT REASON, emit_ask MSG AGENT REASON,
# emit_continue true|false MSG REASON, and host_skip INPUT. Installed trees
# carry lib/verdict_<host>.sh; the pack tree resolves hosts/<host>/.
# A missing verdict file exits 2: Claude denies on 2, Cursor fails closed on
# any non-JSON exit.
load_verdict() {
  local host="${BRIDLE_HOST:-cursor}" f
  for f in "$KLEOS_HOOK_LIB/verdict_$host.sh" "$KLEOS_HOOK_LIB/../../hosts/$host/verdict.sh"; do
    if [[ -f "$f" ]]; then
      # shellcheck source=/dev/null
      source "$f"
      return 0
    fi
  done
  echo "bridle: no verdict file for host '$host'; denied (failClosed). Reinstall the pack." >&2
  exit 2
}

# gate_input: loads the host verdict and reads stdin into INPUT. Returns 1
# when the host defers this payload (host_skip).
gate_input() {
  load_verdict
  INPUT="$(hook_stdin)"
  ! host_skip "$INPUT"
}
