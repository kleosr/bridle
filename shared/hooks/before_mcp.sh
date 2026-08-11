#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
mkdir -p "$STATE"
TOOL="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
TIN="$(echo "$INPUT" | jq -r '.tool_input // empty | if type=="string" then . else tostring end' 2>/dev/null || true)"
BLOB="${TOOL} ${TIN}"
printf '%s | MCP | %s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "${TOOL:0:80}" >>"$STATE/session.log" 2>/dev/null || true
if printf '%s' "$BLOB" | grep -qiE '(rm -rf|/etc/passwd|drop database|exfiltrat|eval\(|child_process|base64 -d.*\|.*sh)'; then
  emit_deny "AUTONOMY BLOCK: MCP tool call matches a dangerous pattern. Human approval required. tool=${TOOL:0:60}"
  exit 0
fi
emit_allow
exit 0
