#!/usr/bin/env bash
set -euo pipefail
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$HERE/lib/common.sh"
resolve_root

STATE="$(state_dir)"; HANDOFF="$ROOT/HANDOFF.md"; POLICY="$HERE/policy/intent.json"
MAX_BODY="$(jq -r '.max_intent_body_lines // 6' "$POLICY" 2>/dev/null || echo 6)"
MAX_ANCH="$(jq -r '.max_named_anchors // 5' "$POLICY" 2>/dev/null || echo 5)"
INPUT="$(cat)"
STATUS="$(echo "$INPUT" | jq -r 'if .status == null then "" else .status end' 2>/dev/null || true)"
[[ -n "$STATUS" && "$STATUS" != "completed" ]] && { emit_quiet; exit 0; }
if ! is_agent_mode; then
  rm -rf "$STATE"; mkdir -p "$STATE"
  emit_quiet; exit 0
fi
MSG_N="$(echo "$INPUT" | jq -r '((.messages // .transcript // .conversation // []) | if type=="array" then length else 0 end)' 2>/dev/null || echo 0)"
MSG_N="${MSG_N//[!0-9]}"
[[ -z "$MSG_N" ]] && MSG_N=0
TURN="$(echo "$INPUT" | jq -r '
  def to_text:
    if type == "array"
    then map(select((.type // "text") == "text") | (.text // .content // "")) | join("\n")
    else tostring end;
  ((.messages // .transcript // .conversation // []) | if type=="array" then . else [] end) as $arr
  | ([range(0; ($arr | length)) | select(
      (($arr[.].role // $arr[.].type // "") | test("user|human"; "i"))
      and (($arr[.].content // "") | type) == "string"
    )]) as $realUserIdxs
  | (if ($realUserIdxs | length) > 0 then ($realUserIdxs | last) + 1 else 0 end) as $start
  | [$arr[$start:][] | select((.role // .type // "") | test("assistant"; "i")) | ((.content // .text // "") | to_text)]
  | join("\n")' 2>/dev/null || true)"
[[ -z "$TURN" || "$TURN" == "null" ]] && TURN=""
PROSE="$(printf '%s\n' "$TURN" | awk 'BEGIN{f=0} /^```/{f=1-f;next} !f')"
source "$HERE/lib/stop_rules.sh"
rules_run
