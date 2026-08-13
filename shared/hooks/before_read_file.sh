#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
mkdir -p "$STATE"
FILE_PATH="$(echo "$INPUT" | jq -r '.file_path // .tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
POL="$HERE/policy/secret_paths.ere"
if [[ -n "$FILE_PATH" && -f "$POL" ]] && printf '%s' "$FILE_PATH" | grep -qE -f "$POL"; then
  emit_deny "AUTONOMY BLOCK: reading sensitive file '$FILE_PATH' blocked to protect secrets from model context. Read it yourself if needed."
  exit 0
fi
if [[ -n "$FILE_PATH" ]]; then
  printf '%s\n' "$FILE_PATH" >>"$STATE/reads" 2>/dev/null || true
fi
emit_quiet
