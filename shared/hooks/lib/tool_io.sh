#!/usr/bin/env bash

extract_tool_name() {
  printf '%s' "$1" | jq -r '.tool_name // .name // empty' 2>/dev/null || true
}

extract_file_path() {
  printf '%s' "$1" | jq -r '
    .tool_input.file_path
    // .tool_input.filePath
    // .tool_input.path
    // .tool_input.target_notebook
    // .file_path
    // empty
  ' 2>/dev/null || true
}

stamp_write() {
  local fp="$1"
  [[ -z "${fp:-}" || -z "${STATE:-}" ]] && return 0
  mkdir -p "$STATE"
  printf '%s\n' "$fp" >>"$STATE/writes" 2>/dev/null || true
}

tool_family() {
  case "$1" in
    Write|StrReplace|EditNotebook) printf 'write' ;;
    Delete) printf 'delete' ;;
    Shell|shell) printf 'shell' ;;
    Read|Grep|Glob) printf 'read' ;;
    *) printf 'other' ;;
  esac
}
