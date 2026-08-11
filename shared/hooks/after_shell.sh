#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
mkdir -p "$STATE"
CMD="$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null || true)"
DURATION="$(echo "$INPUT" | jq -r '.duration // "?"' 2>/dev/null || echo "?")"
SANDBOX="$(echo "$INPUT" | jq -r '.sandbox // "?"' 2>/dev/null || echo "?")"
OUT_LEN="$(echo "$INPUT" | jq -r '(.output // "") | length' 2>/dev/null || echo 0)"
printf '%s | SHELL | duration=%s sandbox=%s out_len=%s | %s\n' \
  "$(date +%Y-%m-%d\ %H:%M:%S)" "$DURATION" "$SANDBOX" "$OUT_LEN" "${CMD:0:200}" >>"$STATE/session.log" 2>/dev/null || true
emit_quiet
