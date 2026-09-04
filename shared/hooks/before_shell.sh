#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/shell_gate.sh"
source "$HERE/lib/shell_fleet.sh"
INPUT="$(cat)"
if ! CMD="$(printf '%s' "$INPUT" | jq -r '.command // .tool_input.command // .tool_input.cmd // empty' 2>/dev/null)"; then
  emit_ask "kleosrules: beforeShellExecution payload is not JSON, so the command could not be inspected. Approve manually if intended; run bash scripts/doctor.sh."
  exit 0
fi
[[ -z "$CMD" ]] && { emit_allow; exit 0; }
if shell_is_fleet_sync "$CMD"; then emit_allow; exit 0; fi
if ! gate_shell_command "$CMD"; then
  exit 0
fi
emit_allow
exit 0
