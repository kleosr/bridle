#!/usr/bin/env bash
# Resolve Node for hook JSON. jq is not on the hook path.

# Resolution is cached in the calling shell (KLEOS_JSON_RESOLVED). Re-probing
# on each json_run inside a $(...) subshell cost an extra interpreter spawn per
# event (~100 ms on MSYS) on the native Read/Shell hot path.
if ! declare -F kleos_abs_dir >/dev/null 2>&1; then
  _jsrc="${BASH_SOURCE[0]//\\//}"
  _jlib="${_jsrc%/*}"
  [[ "$_jlib" == "$_jsrc" || -z "$_jlib" ]] && _jlib="."
  # shellcheck source=selfdir.sh
  source "$_jlib/selfdir.sh"
  unset _jsrc _jlib
fi
_jsrc="${BASH_SOURCE[0]//\\//}"
KLEOS_JSON_DIR="${KLEOS_JSON_DIR:-$(kleos_abs_dir "$_jsrc")}"
unset _jsrc

# A forced KLEOS_JSON_BIN always wins over a cached pick.
json_pick() {
  local bin
  if [[ -n "${KLEOS_JSON_BIN:-}" ]]; then
    [[ -x "$KLEOS_JSON_BIN" ]] || return 1
    KLEOS_JSON_RESOLVED="$KLEOS_JSON_BIN"
    return 0
  fi
  [[ -n "${KLEOS_JSON_RESOLVED:-}" ]] && return 0
  bin="$(type -P node 2>/dev/null)" || return 1
  "$bin" "$KLEOS_JSON_DIR/json_tool.js" ping >/dev/null 2>&1 || return 1
  KLEOS_JSON_RESOLVED="$bin"
}

json_run() {
  json_pick || return 1
  "$KLEOS_JSON_RESOLVED" "$KLEOS_JSON_DIR/json_tool.js" "$@"
}

json_available() {
  json_pick >/dev/null 2>&1
}
