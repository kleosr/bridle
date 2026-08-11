#!/usr/bin/env bash
set -euo pipefail
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$HERE/lib/common.sh"
resolve_root

HANDOFF="$ROOT/HANDOFF.md"; POLICY="$HERE/policy/intent.json"
MAX_BODY="$(jq -r '.max_intent_body_lines // 6' "$POLICY" 2>/dev/null || echo 6)"
MAX_ANCH="$(jq -r '.max_named_anchors // 5' "$POLICY" 2>/dev/null || echo 5)"
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
STATUS="$(echo "$INPUT" | jq -r 'if .status == null then "" else .status end' 2>/dev/null || true)"
[[ -n "$STATUS" && "$STATUS" != "completed" ]] && { emit_quiet; exit 0; }
if ! is_agent_mode; then
  rm -rf "$STATE"; mkdir -p "$STATE"
  emit_quiet; exit 0
fi
if [[ "$(cat "$STATE/route" 2>/dev/null || echo code)" == "chat" && ! -s "$STATE/writes" ]]; then
  emit_quiet; exit 0
fi

# Cursor stop payload has status/loop_count + common fields (incl. transcript_path).
# It does NOT include .messages / .transcript / .conversation arrays.
load_transcript_msgs() {
  local path="$1"
  [[ -f "$path" && -r "$path" ]] || return 1
  if jq -e 'type == "array" or has("messages") or has("transcript") or has("conversation")' "$path" >/dev/null 2>&1; then
    jq -c 'if type == "array" then . else (.messages // .transcript // .conversation // []) end' "$path" 2>/dev/null || return 1
    return 0
  fi
  # JSONL (Cursor / Claude-compat transcript lines)
  jq -s -c '
    map(
      if .message then
        {role: (.message.role // .type // "unknown"), content: (.message.content // .message.text // "")}
      else
        {role: (.role // .type // "unknown"), content: (.content // .text // "")}
      end
    )
  ' "$path" 2>/dev/null || return 1
}

MSGS_JSON="$(echo "$INPUT" | jq -c '(.messages // .transcript // .conversation // null) | if type == "array" then . else null end' 2>/dev/null || echo null)"
if [[ "$MSGS_JSON" == "null" || -z "$MSGS_JSON" ]]; then
  TP="$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
  [[ -z "$TP" || "$TP" == "null" ]] && TP="${CURSOR_TRANSCRIPT_PATH:-}"
  mkdir -p "$STATE"
  if [[ -z "$TP" ]]; then
    printf '%s | ERROR | stop_gate: no messages array and no transcript_path — fail open (not rules_accept)\n' \
      "$(date +%Y-%m-%d\ %H:%M:%S)" >>"$STATE/session.log" 2>/dev/null || true
    emit_quiet; exit 0
  fi
  if ! MSGS_JSON="$(load_transcript_msgs "$TP")"; then
    printf '%s | ERROR | stop_gate: transcript missing/unreadable path=%s — fail open (not rules_accept)\n' \
      "$(date +%Y-%m-%d\ %H:%M:%S)" "$TP" >>"$STATE/session.log" 2>/dev/null || true
    emit_quiet; exit 0
  fi
fi

MSG_N="$(printf '%s' "$MSGS_JSON" | jq -r 'length' 2>/dev/null || echo 0)"
MSG_N="${MSG_N//[!0-9]}"
[[ -z "$MSG_N" ]] && MSG_N=0
TURN="$(printf '%s' "$MSGS_JSON" | jq -r '
  def to_text:
    if type == "array"
    then map(select((.type // "text") == "text") | (.text // .content // "")) | join("\n")
    else tostring end;
  . as $arr
  | ([range(0; ($arr | length)) | select(
      (($arr[.].role // $arr[.].type // "") | test("user|human"; "i"))
      and (($arr[.].content // "") | type) == "string"
    )]) as $realUserIdxs
  | (if ($realUserIdxs | length) > 0 then ($realUserIdxs | last) + 1 else 0 end) as $start
  | [$arr[$start:][] | select((.role // .type // "") | test("assistant"; "i")) | ((.content // .text // "") | to_text)]
  | join("\n")' 2>/dev/null || true)"
[[ -z "$TURN" || "$TURN" == "null" ]] && TURN=""
PROSE="$(printf '%s\n' "$TURN" | awk 'BEGIN{f=0} /^```/{f=1-f;next} !f')"
if [[ -z "$PROSE" && "${MSG_N:-0}" -gt 0 ]]; then
  mkdir -p "$STATE"
  local_keys="$(echo "$INPUT" | jq -r 'if type=="object" then (keys | join(",")) else "?" end' 2>/dev/null || echo "?")"
  printf '%s | CANARY | stop_gate empty PROSE with MSG_N=%s keys=%s (transcript-backed)\n' \
    "$(date +%Y-%m-%d\ %H:%M:%S)" "${MSG_N}" "$local_keys" >>"$STATE/session.log" 2>/dev/null || true
fi
source "$HERE/lib/stop_rules.sh"
rules_run
