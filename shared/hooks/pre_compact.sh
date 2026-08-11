#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
mkdir -p "$STATE"
TRIGGER="$(echo "$INPUT" | jq -r '.trigger // "?"' 2>/dev/null || echo "?")"
PCT="$(echo "$INPUT" | jq -r '.context_usage_percent // "?"' 2>/dev/null || echo "?")"
printf '%s | PRECOMPACT | trigger=%s usage=%s\n' \
  "$(date +%Y-%m-%d\ %H:%M:%S)" "$TRIGGER" "$PCT" >>"$STATE/session.log" 2>/dev/null || true
# Observational: remind grounding after compaction (Cursor shows user_message).
jq -n --arg m "Context compacted (${TRIGGER}). Re-Read HANDOFF.md tail + your current INTENT (edit:|NEW: tags + Done-when) before the next Write." \
  '{user_message:$m}'
