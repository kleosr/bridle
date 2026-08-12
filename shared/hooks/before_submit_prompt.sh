#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/culture_gate.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
mkdir -p "$STATE"
: >"$STATE/writes"
date +%s >"$STATE/session_ts"
MODE="$(echo "$INPUT" | jq -r '.composer_mode // empty' 2>/dev/null || true)"
[[ -z "$MODE" ]] && MODE="agent"
printf '%s\n' "$MODE" >"$STATE/mode"
if [[ "$MODE" != "agent" ]]; then
  emit_continue true; exit 0
fi
PROMPT="$(echo "$INPUT" | jq -r '.prompt // .user_prompt // .message // .text // empty' 2>/dev/null || true)"
if printf '%s' "$PROMPT" | grep -qE '(ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----)'; then
  emit_continue false "Blocked: prompt looks like it contains a secret/token (ghp_/sk-/AKIA/private key). Remove credentials and resubmit."
  exit 0
fi
ROUTE="code"
printf '%s\n' "$PROMPT" >"$STATE/current_intent.md"
printf '%s' "$PROMPT" | grep -oE '(edit|NEW):[A-Za-z0-9_./+=-]+' | sed 's/^[^:]*://' \
  | grep -vx 'path' >"$STATE/allowed_files.md" 2>/dev/null || true
PROMPT_NORM="$(printf '%s' "$PROMPT" | iconv -f UTF-8 -t ASCII//TRANSLIT//IGNORE 2>/dev/null | tr -d "'\`~^" || true)"
[[ -z "$PROMPT_NORM" ]] && PROMPT_NORM="$PROMPT"
CODE_RE='(edit:|NEW:|\.(sh|bash|zsh|py|rb|js|mjs|cjs|ts|tsx|jsx|go|rs|c|cc|cpp|h|hpp|java|kt|swift|php|lua|sql|json|ya?ml|toml|md|ps1)|src/|tests?/|docs/|fix|corrige|corrije|bug|error|falla|break|rompe|implement|refactor|crea|create|edita|edit|agrega|add|delete|elimin|test|commit|push|merge|deploy|instal|actualiza|update|hook|archiv|file|script)'
printf '%s' "$PROMPT_NORM" | grep -qiE "$CODE_RE" || ROUTE="chat"
printf '%s\n' "$ROUTE" >"$STATE/route"
OUTCOMES=$(printf '%s' "$PROMPT_NORM" | grep -oiE '\b(conecta|implementa|arregla|crea|asegurate?|verifica|anhade|remueve|actualiza|refactoriza|configura|despliega|integra|construye|optimiza|corrije|migra|documenta|escribe|disena|connect|implement|fix|create|ensure|verify|add|remove|update|refactor|configure|deploy|integrate|build|optimize|migrate|document|write|design|test)\b' | wc -l || true)
OUTCOMES="${OUTCOMES//[!0-9]}"
[[ -z "$OUTCOMES" || "$OUTCOMES" -lt 1 ]] && OUTCOMES=1
[[ "$OUTCOMES" -gt 5 ]] && OUTCOMES=5
printf '%s\n' "$OUTCOMES" >"$STATE/outcomes.md"
NUDGE=""
if [[ "$ROUTE" == "code" ]]; then
  PATH_HITS="$(printf '%s' "$PROMPT" | grep -oE '\b(src|tests?|docs|shared|scripts|lib|app|hooks)/[A-Za-z0-9_./+=-]+\.[A-Za-z0-9]+|\b[A-Za-z0-9_.-]+\.(ts|tsx|js|jsx|sh|py|go|rs|md|json)\b' 2>/dev/null | head -n 8 || true)"
  UNTAGGED=""
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    grep -qxF "$p" "$STATE/allowed_files.md" 2>/dev/null && continue
    base="$(basename "$p")"
    grep -qxF "$base" "$STATE/allowed_files.md" 2>/dev/null && continue
    UNTAGGED="${UNTAGGED}${UNTAGGED:+ }$p"
  done <<EOF
$PATH_HITS
EOF
  if [[ -n "$UNTAGGED" ]]; then
    NUDGE="FILE_MAP nudge: prompt mentions paths without edit:|NEW: tags (${UNTAGGED}). Declare them in INTENT chat prose — not a block, proceeding."
  fi
  CULT="$(culture_submit_nudge "$PROMPT" "$ROUTE" || true)"
  if [[ -n "$CULT" ]]; then
    if [[ -n "$NUDGE" ]]; then NUDGE="${NUDGE} ${CULT}"; else NUDGE="$CULT"; fi
  fi
fi
if [[ -n "$NUDGE" ]]; then
  emit_continue true "$NUDGE"
else
  emit_continue true
fi
