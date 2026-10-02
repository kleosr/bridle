#!/usr/bin/env bash
# Cursor verdicts: {"permission": allow|deny|ask} for shell and read,
# {"continue": bool} for beforeSubmitPrompt. `turn-check` runs the stop sensor.

if [[ "${1:-}" == "turn-check" ]]; then
  emit_quiet() { printf '{}\n'; exit 0; }
  command -v jq >/dev/null 2>&1 || emit_quiet
  INPUT="$(cat)"
  ROOT="$(printf '%s' "$INPUT" | jq -r '.workspace_roots[0] // .cwd // ""' 2>/dev/null)" || emit_quiet
  STATUS="$(printf '%s' "$INPUT" | jq -r '.status // "completed"' 2>/dev/null)"
  [[ "$STATUS" == "completed" ]] || emit_quiet
  [[ -n "$ROOT" && -d "$ROOT" ]] || emit_quiet
  QG="$HOME/.cursor/skills/code-architecture/scripts/quality-gate.mjs"
  command -v node >/dev/null 2>&1 || emit_quiet
  [[ -f "$QG" ]] || emit_quiet
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit_quiet
  OUT=""; EC=0
  OUT="$(cd "$ROOT" && node "$QG" 2>&1)" || EC=$?
  (( EC == 0 )) && emit_quiet
  MSG=$'bridle: turn-check: quality-gate failed on this diff.\n\nFix every finding and re-run the gate.\n\n'
  MSG+="$OUT"
  jq -cn --arg m "$MSG" '{followup_message: $m}'
  exit 0
fi

json_emit() {
  local kind="$1"
  KLEOS_JSON_MSG="${2:-}" KLEOS_JSON_REASON="${3:-}" KLEOS_JSON_AGENT="${4:-}" \
    KLEOS_JSON_CONTINUE="${5:-}" \
    json_run emit "$kind"
}

emit_perm() {
  local kind="$1" msg="$2" reason="$3" agent="${4:-}"
  json_emit "$kind" "$msg" "$reason" "$agent" && return 0
  echo "{\"permission\":\"$kind\",\"user_message\":\"kleosrules: JSON tool required\",\"reason\":\"missing-json\"}"
}

# A bare allow is a constant; spawning the codec to print it cost one
# interpreter start per allowed Read/Shell on the native hot path.
emit_allow() {
  if [[ -z "${1:-}" ]]; then
    echo '{"permission":"allow"}'
    return 0
  fi
  json_emit allow "$1" && return 0
  echo '{"permission":"allow"}'
}

emit_deny() {
  emit_perm deny "$1" "${3:-deny}" "$2"
}

emit_ask() {
  emit_perm ask "$1" "${3:-ask}" "$2"
}

emit_continue() {
  local cont="${1:-true}" msg="${2:-}" reason="${3:-}"
  if [[ "$cont" == "false" ]]; then
    json_emit continue "$msg" "${reason:-block}" "" false && return 0
    printf '%s\n' "{\"continue\":false,\"reason\":\"${reason:-block}\"}"
    return 0
  fi
  json_emit continue "$msg" && return 0
  echo '{"continue":true}'
}

host_skip() {
  local ledger conv_re='"conversation_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_-]+)"'
  local skill_re='"file_path"[[:space:]]*:[[:space:]]*"[^"]*/skills/([A-Za-z0-9_-]+)/SKILL\.md"'
  [[ "$1" =~ $conv_re ]] || return 1
  ledger="${XDG_STATE_HOME:-$HOME/.local/state}/bridle/cursor/${BASH_REMATCH[1]}.jsonl"
  if [[ "$1" == *'"hook_event_name"'*'"beforeSubmitPrompt"'* ]]; then
    { mkdir -p "${ledger%/*}" && : >"$ledger"; } 2>/dev/null || true
  elif [[ "$1" =~ $skill_re ]]; then
    { mkdir -p "${ledger%/*}" && printf '{"skills":["%s"]}\n' "${BASH_REMATCH[1]}" >>"$ledger"; } 2>/dev/null || true
  fi
  return 1
}
