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
if [[ ! -f "$NOW" ]]; then
  emit_quiet; exit 0
fi
POL="$HERE/policy/secret_tokens.ere"
if [[ -f "$POL" ]] && grep -qE -f "$POL" "$NOW"; then
  emit_quiet
  exit 0
fi
emit_context "Read ${NOW} (Now, State, Limits, Proof, Next)."
