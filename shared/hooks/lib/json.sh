#!/usr/bin/env bash
# Resolve CPython or Node for hook JSON. jq is not on the hook path.

# Resolution is cached in the calling shell (KLEOS_JSON_RESOLVED / _KIND /
# _DIR). Every hook used to re-probe on each json_run inside a $(...) subshell,
# which threw the cache away and cost 2-3 extra interpreter spawns per event
# (~100 ms each on MSYS) on the native Read/Shell hot path.
KLEOS_JSON_DIR="${KLEOS_JSON_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

json_lib_dir() {
  printf '%s\n' "$KLEOS_JSON_DIR"
}

json_pick() {
  local dir="$KLEOS_JSON_DIR" bin
  if [[ -n "${KLEOS_JSON_BIN:-}" ]]; then
    [[ -x "$KLEOS_JSON_BIN" ]] || return 1
    KLEOS_JSON_RESOLVED="$KLEOS_JSON_BIN"
    KLEOS_JSON_KIND="${KLEOS_JSON_KIND:-$(json_kind_of "$KLEOS_JSON_BIN")}"
    printf '%s\n' "$KLEOS_JSON_BIN"
    return 0
  fi
  if [[ -n "${KLEOS_JSON_RESOLVED:-}" && -n "${KLEOS_JSON_KIND:-}" ]]; then
    printf '%s\n' "$KLEOS_JSON_RESOLVED"
    return 0
  fi
  # Node first: ~3x faster startup than CPython and prints nothing to stderr.
  # On Windows, `python3` on PATH is often the Microsoft Store stub (a fake that
  # exits non-zero), so probing it costs a failed process run before we land on
  # a real interpreter. Node sidesteps both. Falls through to CPython if absent.
  if bin="$(type -P node 2>/dev/null)" && "$bin" "$dir/json_tool.js" ping >/dev/null 2>&1; then
    KLEOS_JSON_RESOLVED="$bin"
    KLEOS_JSON_KIND=node
    printf '%s\n' "$bin"
    return 0
  fi
  if bin="$(type -P python3 2>/dev/null)" && "$bin" "$dir/json_tool.py" ping >/dev/null 2>&1; then
    KLEOS_JSON_RESOLVED="$bin"
    KLEOS_JSON_KIND=python
    printf '%s\n' "$bin"
    return 0
  fi
  if bin="$(type -P python 2>/dev/null)" && "$bin" "$dir/json_tool.py" ping >/dev/null 2>&1; then
    KLEOS_JSON_RESOLVED="$bin"
    KLEOS_JSON_KIND=python
    printf '%s\n' "$bin"
    return 0
  fi
  if bin="$(type -P py 2>/dev/null)" && "$bin" -3 "$dir/json_tool.py" ping >/dev/null 2>&1; then
    KLEOS_JSON_RESOLVED="$bin"
    KLEOS_JSON_KIND=py
    printf '%s\n' "$bin"
    return 0
  fi
  return 1
}

# Interpreter family from the binary name, used when KLEOS_JSON_BIN is forced.
json_kind_of() {
  local base="${1##*/}"
  case "$base" in
    node|node.exe|nodejs) printf 'node' ;;
    py|py.exe) printf 'py' ;;
    *) printf 'python' ;;
  esac
}

# json_pick is cheap once resolved (no spawn), so both entry points call it
# unconditionally; a forced KLEOS_JSON_BIN always wins over a cached pick.
json_run() {
  local dir="$KLEOS_JSON_DIR" bin
  json_pick >/dev/null || return 1
  bin="$KLEOS_JSON_RESOLVED"
  case "${KLEOS_JSON_KIND:-$(json_kind_of "$bin")}" in
    node) "$bin" "$dir/json_tool.js" "$@" ;;
    py) "$bin" -3 "$dir/json_tool.py" "$@" ;;
    *) "$bin" "$dir/json_tool.py" "$@" ;;
  esac
}

json_available() {
  json_pick >/dev/null 2>&1
}
