#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/tool_io.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
FILE_PATH="$(extract_file_path "$INPUT")"
[[ -n "$FILE_PATH" ]] && stamp_write "$FILE_PATH"
if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
  LINES="$(wc -l < "$FILE_PATH" 2>/dev/null || echo 0)"
  LINES="${LINES//[!0-9]}"; [[ -z "$LINES" ]] && LINES=0
  mkdir -p "$STATE"
  printf '%s | EDIT | loc=%s | %s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "$LINES" "$FILE_PATH" \
    >>"$STATE/session.log" 2>/dev/null || true
fi
emit_quiet
