#!/usr/bin/env bash
# beforeSubmitPrompt: block prompts that look like they contain a secret/token.
# Fail closed: unparseable input, missing policy, or missing JSON tool all block.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
INPUT="$(hook_stdin)"
POL="$HERE/policy/secret_tokens.ere"
if ! json_available; then
  emit_continue false "kleosrules: Python or Node is unavailable; prompt blocked (failClosed). Install python3 or node." missing-json
  exit 0
fi
if [[ -z "$INPUT" ]] || ! DECODE="$(printf '%s' "$INPUT" | json_run decode-submit)"; then
  emit_continue false "Blocked: prompt JSON could not be parsed. Remove credentials and resubmit." malformed
  exit 0
fi
eval "$DECODE"
if [[ ! -f "$POL" ]]; then
  emit_continue false "kleosrules: policy/secret_tokens.ere is missing; prompt blocked (failClosed). Run FORCE=1 bash scripts/install.sh." missing-policy
  exit 0
fi
if [[ -n "${PROMPT:-}" ]] && printf '%s' "$PROMPT" | grep -qE -f "$POL"; then
  emit_continue false "Blocked: prompt looks like it contains a secret/token. Remove credentials and resubmit." secret-token
  exit 0
fi
emit_continue true
