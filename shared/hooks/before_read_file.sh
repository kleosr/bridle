#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
command -v jq >/dev/null 2>&1 || { echo '{}'; exit 0; }
INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | jq -r '.file_path // .tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
POL="$HERE/policy/secret_paths.ere"
if [[ -n "$FILE_PATH" && -f "$POL" ]] && printf '%s' "$FILE_PATH" | grep -qE -f "$POL"; then
  emit_deny "AUTONOMY BLOCK: reading sensitive file '$FILE_PATH' blocked to protect secrets from model context. Read it yourself if needed."
  exit 0
fi
emit_quiet
