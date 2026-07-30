#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
POLICY="$HERE/policy/lean.json"
MAX="$(jq -r '.file_loc_max // 700' "$POLICY" 2>/dev/null || echo 700)"
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "StrReplace" ]]; then
  echo '{"action":"allow"}'
  exit 0
fi
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  echo '{"action":"allow"}'
  exit 0
fi
LINES=$(wc -l < "$FILE_PATH")
if [[ "$LINES" -gt "$MAX" ]]; then
  jq -n --arg m "MECHANICAL DENY: file exceeds ${MAX} LOC ($LINES). Split." \
    '{action:"deny", user_message:$m}'
  exit 2
fi
echo '{"action":"allow"}'
exit 0
