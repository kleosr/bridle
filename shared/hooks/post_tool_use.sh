#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/metrics.sh"
source "$HERE/lib/tool_io.sh"
source "$HERE/lib/scorecard.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
mkdir -p "$STATE"
TOOL_NAME="$(extract_tool_name "$INPUT")"
FILE_PATH="$(extract_file_path "$INPUT")"
[[ -z "$FILE_PATH" ]] && { emit_quiet; exit 0; }
stamp_write "$FILE_PATH"
case "$(tool_family "$TOOL_NAME")" in
  delete) emit_quiet; exit 0 ;;
esac
MSG="$(scorecard_message "$FILE_PATH" "$HERE/policy/lean.json" || true)"
if [[ -n "${MSG:-}" ]]; then
  emit_context "$MSG"
else
  emit_quiet
fi
