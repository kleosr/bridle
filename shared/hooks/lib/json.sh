#!/usr/bin/env bash
# Resolve CPython or Node for hook JSON. jq is not on the hook path.

json_lib_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

json_pick() {
  local dir bin
  dir="$(json_lib_dir)"
  if [[ -n "${KLEOS_JSON_BIN:-}" ]]; then
    [[ -x "$KLEOS_JSON_BIN" ]] || return 1
    printf '%s\n' "$KLEOS_JSON_BIN"
    return 0
  fi
  if [[ -n "${KLEOS_JSON_RESOLVED:-}" ]]; then
    printf '%s\n' "$KLEOS_JSON_RESOLVED"
    return 0
  fi
  if bin="$(type -P python3 2>/dev/null)" && "$bin" "$dir/json_tool.py" ping >/dev/null 2>&1; then
    KLEOS_JSON_RESOLVED="$bin"
    printf '%s\n' "$bin"
    return 0
  fi
  if bin="$(type -P python 2>/dev/null)" && "$bin" "$dir/json_tool.py" ping >/dev/null 2>&1; then
    KLEOS_JSON_RESOLVED="$bin"
    printf '%s\n' "$bin"
    return 0
  fi
  if bin="$(type -P py 2>/dev/null)" && "$bin" -3 "$dir/json_tool.py" ping >/dev/null 2>&1; then
    KLEOS_JSON_RESOLVED="$bin"
    KLEOS_JSON_KIND=py
    printf '%s\n' "$bin"
    return 0
  fi
  if bin="$(type -P node 2>/dev/null)" && "$bin" "$dir/json_tool.js" ping >/dev/null 2>&1; then
    KLEOS_JSON_RESOLVED="$bin"
    KLEOS_JSON_KIND=node
    printf '%s\n' "$bin"
    return 0
  fi
  return 1
}

json_run() {
  local dir bin base
  dir="$(json_lib_dir)"
  bin="$(json_pick)" || return 1
  [[ -n "$bin" ]] || return 1
  if [[ "${KLEOS_JSON_KIND:-}" == "node" ]] || [[ "$(basename "$bin")" == node || "$(basename "$bin")" == node.exe || "$(basename "$bin")" == nodejs ]]; then
    "$bin" "$dir/json_tool.js" "$@"
    return $?
  fi
  if [[ "${KLEOS_JSON_KIND:-}" == "py" ]] || [[ "$(basename "$bin")" == py || "$(basename "$bin")" == py.exe ]]; then
    "$bin" -3 "$dir/json_tool.py" "$@"
    return $?
  fi
  "$bin" "$dir/json_tool.py" "$@"
}

json_available() {
  json_pick >/dev/null 2>&1
}
