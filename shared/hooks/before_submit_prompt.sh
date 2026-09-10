#!/usr/bin/env bash
# beforeSubmitPrompt: block prompts that look like they contain a secret/token.
# Fail closed: unparseable input, missing policy, or missing jq all block.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
INPUT="$(cat)"
POL="$HERE/policy/secret_tokens.ere"
if [[ -z "$INPUT" ]] || ! printf '%s' "$INPUT" | jq empty >/dev/null 2>&1; then
  emit_continue false "Blocked: prompt JSON could not be parsed. Remove credentials and resubmit." malformed
  exit 0
fi
if [[ ! -f "$POL" ]]; then
  emit_continue false "kleosrules: policy/secret_tokens.ere is missing; prompt blocked (failClosed). Run FORCE=1 bash scripts/install.sh." missing-policy
  exit 0
fi
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // .user_prompt // .message // .text // empty' 2>/dev/null)" || {
  emit_continue false "Blocked: prompt JSON could not be parsed. Remove credentials and resubmit." malformed
  exit 0
}
if [[ -n "$PROMPT" ]] && printf '%s' "$PROMPT" | grep -qE -f "$POL"; then
  emit_continue false "Blocked: prompt looks like it contains a secret/token. Remove credentials and resubmit." secret-token
  exit 0
fi
emit_continue true
