#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
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
ROUTE="code"
printf '%s\n' "$PROMPT" >"$STATE/current_intent.md"
printf '%s' "$PROMPT" | grep -oE '(edit|NEW):[A-Za-z0-9_./+=-]+' | sed 's/^[^:]*://' \
  | grep -vx 'path' >"$STATE/allowed_files.md" 2>/dev/null || true
# BSD iconv transliterates but exits 1 and marks approximations ('e ~n); strip the markers.
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
# Cursor beforeSubmitPrompt: continue/block only. DUTY context → sessionStart.
emit_continue true
