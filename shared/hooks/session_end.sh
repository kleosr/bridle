#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
if [[ -n "$CONV_ID" && "$CONV_ID" != "default" ]]; then
  find "$ROOT/state" -maxdepth 1 -mindepth 1 -type d -mtime +2 -exec rm -rf {} \; 2>/dev/null || true
fi
emit_quiet
