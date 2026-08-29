#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
INPUT="$(cat)"
PROMPT="$(echo "$INPUT" | jq -r '.prompt // .user_prompt // .message // .text // empty' 2>/dev/null)" || {
  emit_continue false "Blocked: prompt JSON could not be parsed. Remove credentials and resubmit."
  exit 0
}
POL="$HERE/policy/secret_tokens.ere"
if [[ -n "$PROMPT" && -f "$POL" ]] && printf '%s' "$PROMPT" | grep -qE -f "$POL"; then
  emit_continue false "Blocked: prompt looks like it contains a secret/token. Remove credentials and resubmit."
  exit 0
fi
emit_continue true
