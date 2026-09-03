#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
INPUT="$(cat)"
POL="$HERE/policy/secret_paths.ere"
if ! FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.file_path // .tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"; then
  emit_deny "kleosrules: beforeReadFile payload is not JSON; read denied (failClosed). Run bash scripts/doctor.sh."
  exit 0
fi
if [[ ! -f "$POL" ]]; then
  emit_deny "kleosrules: policy/secret_paths.ere is missing; read denied (failClosed). Run FORCE=1 bash scripts/install.sh."
  exit 0
fi
if [[ -n "$FILE_PATH" ]] && printf '%s' "$FILE_PATH" | grep -qE -f "$POL"; then
  emit_deny "AUTONOMY BLOCK: reading sensitive file '$FILE_PATH' blocked to protect secrets from model context. Read it yourself if needed."
  exit 0
fi
emit_allow
