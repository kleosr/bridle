#!/usr/bin/env bash
# Host I/O adapter. Gate logic is host-agnostic; this file only maps payload
# fields and verdict JSON. Default: Cursor. Set KLEOS_HOST=claude for Claude Code.

detect_host() {
  if [[ -n "${KLEOS_HOST:-}" ]]; then
    printf '%s' "$KLEOS_HOST"
    return
  fi
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    printf '%s' "claude"
    return
  fi
  printf '%s' "cursor"
}
