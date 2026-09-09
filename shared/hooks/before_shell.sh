#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/shell_gate.sh"
source "$HERE/lib/shell_fleet.sh"
INPUT="$(cat)"
if ! TYPE="$(printf '%s' "$INPUT" | jq -r '(.command // .tool_input.command // .tool_input.cmd // null) | type' 2>/dev/null)"; then
  emit_deny "kleosrules: beforeShellExecution payload is not JSON; command denied (failClosed). Run bash scripts/doctor.sh."
  exit 0
fi
case "$TYPE" in
  object|array|number|boolean)
    emit_deny "kleosrules: beforeShellExecution command must be a string; denied (failClosed)."
    exit 0
    ;;
esac
CMD="$(printf '%s' "$INPUT" | jq -r '.command // .tool_input.command // .tool_input.cmd // empty' 2>/dev/null)" || {
  emit_deny "kleosrules: beforeShellExecution payload is not JSON; command denied (failClosed). Run bash scripts/doctor.sh."
  exit 0
}
[[ -z "$CMD" ]] && { emit_allow; exit 0; }
if shell_is_fleet_sync "$CMD"; then
  if [[ -f "shared/config/manifest.json" && -f "shared/hooks/fleet_sync.sh" && -f "scripts/install.sh" ]]; then
    emit_ask "Harness activation request: a relative installer path is not proof of trust. Approve only if this checkout is the trusted kleosrules pack. CMD: ${CMD:0:120}"
  else
    emit_deny "kleosrules: installer path without pack markers denied. Run from the pack root."
  fi
  exit 0
fi
if ! gate_shell_command "$CMD"; then
  exit 0
fi
emit_allow
exit 0
