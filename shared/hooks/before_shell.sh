#!/usr/bin/env bash
# beforeShellExecution: gate the shell command string. Deny > ask > allow.
# Fail closed: non-JSON, non-string command, or missing jq all deny.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/shell_gate.sh"
INPUT="$(cat)"
if ! TYPE="$(printf '%s' "$INPUT" | jq -r '(.command // .tool_input.command // .tool_input.cmd // null) | type' 2>/dev/null)"; then
  emit_deny "kleosrules: beforeShellExecution payload is not JSON; command denied (failClosed). Run bash scripts/doctor.sh." "" malformed
  exit 0
fi
case "$TYPE" in
  object|array|number|boolean)
    emit_deny "kleosrules: beforeShellExecution command must be a string; denied (failClosed)." "" malformed
    exit 0
    ;;
esac
CMD="$(printf '%s' "$INPUT" | jq -r '.command // .tool_input.command // .tool_input.cmd // empty' 2>/dev/null)" || {
  emit_deny "kleosrules: beforeShellExecution payload is not JSON; command denied (failClosed). Run bash scripts/doctor.sh." "" malformed
  exit 0
}
[[ -z "$CMD" ]] && { emit_allow; exit 0; }
# Command cwd comes from the payload when the host provides it; the hook
# process cwd is the hook dir, not the workspace, so never assume ".".
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // .tool_input.cwd // .workspace_roots[0] // empty' 2>/dev/null || true)"
if shell_is_fleet_sync "$CMD"; then
  if [[ -n "$CWD" && -d "$CWD" && -f "$CWD/shared/config/manifest.json" && -f "$CWD/shared/hooks/fleet_sync.sh" && -f "$CWD/scripts/install.sh" ]]; then
    emit_ask "Harness activation request: a relative installer path is not proof of trust. Approve only if this checkout is the trusted kleosrules pack." "" activation
  else
    emit_deny "kleosrules: installer path without pack markers denied. Run from the pack root." "" activation
  fi
  exit 0
fi
if gate_shell_command "$CMD"; then
  exit 0
fi
emit_allow
exit 0
