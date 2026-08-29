#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
INPUT="$(cat)"
resolve_root "$INPUT"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
mkdir -p "$STATE"
MODE="$(echo "$INPUT" | jq -r '.composer_mode // empty' 2>/dev/null || true)"
[[ -z "$MODE" ]] && MODE="agent"
printf '%s\n' "$MODE" >"$STATE/mode"
if [[ "$MODE" == "plan" ]]; then
  emit_quiet; exit 0
fi
NOW="$ROOT/NOW.md"
TAIL=""
if [[ -f "$NOW" ]]; then
  TAIL="$(extract_now "$NOW")"
fi
POL="$HERE/policy/secret_tokens.ere"
if [[ -n "$TAIL" && -f "$POL" ]] && printf '%s' "$TAIL" | grep -qE -f "$POL"; then
  emit_quiet
  exit 0
fi
if [[ -n "$TAIL" ]]; then
  emit_context "NOW:
${TAIL}"
else
  emit_quiet
fi
