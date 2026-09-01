#!/usr/bin/env bash

resolve_root() {
  local d wr
  wr="$(printf '%s' "${1:-}" | jq -r '.workspace_roots[0] // empty' 2>/dev/null || true)"
  [[ "$wr" == "null" ]] && wr=""
  if [[ -n "$wr" && ( -f "$wr/NOW.md" || -f "$wr/AGENTS.md" ) ]]; then
    ROOT="$(cd "$wr" && pwd)"; return 0
  fi
  if [[ -f "$PWD/NOW.md" || -f "$PWD/AGENTS.md" ]]; then
    ROOT="$(cd "$PWD" && pwd)"; return 0
  fi
  for d in "$HERE/.." "$HERE/../.." "$HERE/../../.."; do
    if [[ -f "$d/NOW.md" || -f "$d/AGENTS.md" ]]; then
      ROOT="$(cd "$d" && pwd)"; return 0
    fi
  done
  ROOT="$(cd "$HERE/.." && pwd)"
}

state_dir() {
  if [[ -n "${CONV_ID:-}" && "${CONV_ID:-}" != "default" ]]; then
    printf '%s/state/%s\n' "$ROOT" "$CONV_ID"
  else
    printf '%s/state\n' "$ROOT"
  fi
}

extract_conv_id() {
  local id
  id="$(printf '%s' "$1" | jq -r '.conversation_id // .session_id // empty' 2>/dev/null || true)"
  [[ -z "$id" || "$id" == "null" ]] && id="default"
  printf '%s' "$id"
}

extract_now() {
  local f="$1" body
  [[ -f "$f" ]] || return 0
  body="$(awk '
    BEGIN { keep=0 }
    /^<!-- COMPACTION PROTOCOL/ { exit }
    /^## / {
      keep = ($0 ~ /^## (Now|State|Limits|Proof|Next)[[:space:]]*$/)
    }
    keep { print }
  ' "$f")"
  if [[ -n "$body" ]] && printf '%s\n' "$body" | grep -qE '^## (Now|State|Limits|Proof)[[:space:]]*$'; then
    printf '%s\n' "$body" | head -n 150
  else
    tail -n 40 "$f" | sed -n '/<!-- COMPACTION PROTOCOL/,$d;p' | tail -n 15
  fi
}

emit_allow() {
  local msg="${1:-}"
  if [[ -n "$msg" ]]; then
    jq -n --arg m "$msg" '{permission:"allow", agent_message:$m}'
  else
    echo '{"permission":"allow"}'
  fi
}

emit_deny() {
  local msg="$1" agent="${2:-}"
  if [[ -n "$agent" ]]; then
    jq -n --arg m "$msg" --arg a "$agent" '{permission:"deny", user_message:$m, agent_message:$a}'
  else
    jq -n --arg m "$msg" '{permission:"deny", user_message:$m}'
  fi
}

emit_ask() {
  local msg="$1" agent="${2:-}"
  if [[ -n "$agent" ]]; then
    jq -n --arg m "$msg" --arg a "$agent" '{permission:"ask", user_message:$m, agent_message:$a}'
  else
    jq -n --arg m "$msg" '{permission:"ask", user_message:$m}'
  fi
}

emit_quiet() { echo '{}'; }

emit_context() {
  local ctx="$1"
  jq -n --arg c "$ctx" '{additional_context: $c}'
}

emit_continue() {
  local cont="${1:-true}" msg="${2:-}"
  if [[ "$cont" == "false" ]]; then
    if [[ -n "$msg" ]]; then
      jq -n --arg m "$msg" '{continue:false, user_message:$m}'
    else
      echo '{"continue":false}'
    fi
  else
    if [[ -n "$msg" ]]; then
      jq -n --arg m "$msg" '{continue:true, user_message:$m}'
    else
      echo '{"continue":true}'
    fi
  fi
}
