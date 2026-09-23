#!/usr/bin/env bash
# beforeShellExecution: gate the shell command string. Deny > ask > allow.
# Fail closed: non-JSON, non-string command, or missing JSON tool all deny.
set -euo pipefail
_self="${BASH_SOURCE[0]//\\//}"
_dir="${_self%/*}"; [[ "$_dir" == "$_self" || -z "$_dir" ]] && _dir="."
# shellcheck source=lib/selfdir.sh
source "$_dir/lib/selfdir.sh"
HERE="$(kleos_abs_dir "$_self")"; unset _self _dir
source "$HERE/lib/common.sh"
source "$HERE/lib/shell_gate.sh"
source "$HERE/lib/sql_scope.sh"
INPUT="$(hook_stdin)"
if ! json_available; then
  emit_deny "kleosrules: Python or Node is unavailable; command denied (failClosed). Install python3 or node." "" missing-json
  exit 0
fi
if ! DECODE="$(printf '%s' "$INPUT" | json_run decode-shell)"; then
  emit_deny "kleosrules: beforeShellExecution payload is not JSON; command denied (failClosed). Run bash scripts/doctor.sh." "" malformed
  exit 0
fi
eval "$DECODE"
case "${TYPE:-null}" in
  object|array|number|boolean)
    emit_deny "kleosrules: beforeShellExecution command must be a string; denied (failClosed)." "" malformed
    exit 0
    ;;
esac
[[ -z "${CMD:-}" ]] && { emit_allow; exit 0; }
# Command cwd comes from the payload when the host provides it; the hook
# process cwd is the hook dir, not the workspace, so never assume ".".
if shell_is_fleet_sync "$CMD"; then
  norm_cwd="$(posix_slashes "${CWD:-}")"
  if [[ -n "$norm_cwd" && -d "$norm_cwd" && -f "$norm_cwd/shared/config/manifest.json" && -f "$norm_cwd/shared/hooks/fleet_sync.sh" && -f "$norm_cwd/scripts/install.sh" ]]; then
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
