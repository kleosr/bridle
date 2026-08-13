#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
INPUT="$(cat)"
PROMPT="$(echo "$INPUT" | jq -r '.prompt // .user_prompt // .message // .text // empty' 2>/dev/null || true)"
if printf '%s' "$PROMPT" | grep -qE '(ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|ntn_[A-Za-z0-9]{20,}|AIza[A-Za-z0-9_-]{20,}|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----)'; then
  emit_continue false "Blocked: prompt looks like it contains a secret/token. Remove credentials and resubmit."
  exit 0
fi
emit_continue true
