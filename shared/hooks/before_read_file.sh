#!/usr/bin/env bash
# beforeReadFile: screening deny for sensitive paths (best effort, not
# confidentiality — see SECURITY.md). Fail closed on malformed input or
# missing policy.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/host.sh"
INPUT="$(hook_stdin)"
POL="$HERE/policy/secret_paths.ere"
if ! json_available; then
  emit_deny "kleosrules: Python or Node is unavailable; read denied (failClosed). Install python3 or node." "" missing-json
  exit 0
fi
if ! DECODE="$(printf '%s' "$INPUT" | json_run decode-read)"; then
  emit_deny "kleosrules: beforeReadFile payload is not JSON; read denied (failClosed). Run bash scripts/doctor.sh." "" malformed
  exit 0
fi
eval "$DECODE"
if [[ ! -f "$POL" ]]; then
  emit_deny "kleosrules: policy/secret_paths.ere is missing; read denied (failClosed). Run FORCE=1 bash scripts/install.sh." "" missing-policy
  exit 0
fi
FILE_PATH="$(canon_secret_path "${FILE_PATH:-}")"
if [[ -n "$FILE_PATH" ]] && printf '%s' "$FILE_PATH" | grep -qiE -f "$POL"; then
  emit_deny "AUTONOMY BLOCK: reading a sensitive path is blocked to protect secrets from model context. Read it yourself if needed." "" secret-path
  exit 0
fi
emit_allow
