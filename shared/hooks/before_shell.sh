#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/shell_gate.sh"
INPUT="$(cat)"
if ! CMD="$(printf '%s' "$INPUT" | jq -r '.command // .tool_input.command // .tool_input.cmd // empty' 2>/dev/null)"; then
  emit_ask "kleosrules: beforeShellExecution payload is not JSON, so the command could not be inspected. Approve manually if intended; run bash scripts/doctor.sh."
  exit 0
fi
if [[ -z "$CMD" ]]; then
  emit_ask "kleosrules: beforeShellExecution payload has no command field, so the command could not be inspected. Approve manually if intended; run bash scripts/doctor.sh."
  exit 0
fi
if ! gate_shell_command "$CMD"; then
  exit 0
fi
emit_allow
exit 0
