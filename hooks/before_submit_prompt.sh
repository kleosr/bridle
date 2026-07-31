#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT=""
for d in "$HERE/.." "$HERE/../.." "$HERE/../../.."; do
  if [[ -f "$d/HANDOFF.md" || -f "$d/AGENTS.md" ]]; then
    ROOT="$(cd "$d" && pwd)"; break
  fi
done
[[ -z "$ROOT" ]] && ROOT="$(cd "$HERE/.." && pwd)"
STATE="$ROOT/state"
mkdir -p "$STATE"
date +%s >"$STATE/session_ts"
INPUT="$(cat)"
PROMPT="$(echo "$INPUT" | jq -r '.prompt // .user_prompt // .message // .text // empty' 2>/dev/null || true)"
ROUTE="other"
echo "$PROMPT" | grep -qiE 'implement|fix|refactor|bug|code|patch|cargo|typescript|rust|bash|connect|conecta|wire|api|frontend|backend|component|hook|render|data|fetch|endpoint|función|pantalla|página|landing|database|query|mutation|state|effect|deploy|despliega|build|construye|configura|integra|test|ssh|server|servidor|inventory|inventario|docker|nginx|systemd|service|servicio|deploy|infra|host|vm|container|deploy|rollback|migrate|pipeline|ci\b|cd\b' && ROUTE="code"
echo "$PROMPT" | grep -qiE 'remember|vault|obsidian|handoff|amnesia|session' && ROUTE="memory"
printf '%s\n' "$PROMPT" >"$STATE/current_intent.md"
# Sandbox seed: extract file paths the user mentions in their prompt and snapshot
# them as the allowed set for stop_gate's topology check. Patterns: edit:path,
# NEW:path, bare paths (src/foo.rs, *.ts), or quoted paths. Lines, one per line.
echo "$PROMPT" | grep -oE '(edit|NEW):[A-Za-z0-9_./+=-]+' | sed 's/^[^:]*://' \
  | grep -vx 'path' >"$STATE/allowed_files.md" 2>/dev/null || true
PROMPT_NORM="$(echo "$PROMPT" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$PROMPT")"
OUTCOMES=$(echo "$PROMPT_NORM" | grep -oiE '\b(conecta|implementa|arregla|crea|asegurate?|verifica|anhade|remueve|actualiza|refactoriza|configura|despliega|integra|construye|optimiza|corrije|migra|documenta|escribe|disena|connect|implement|fix|create|ensure|verify|add|remove|update|refactor|configure|deploy|integrate|build|optimize|migrate|document|write|design|test)\b' | wc -l || true)
[[ "$OUTCOMES" -lt 1 ]] && OUTCOMES=1
printf '%s\n' "$OUTCOMES" >"$STATE/outcomes.md"
DUTY="$(jq -r '.duty // empty' "$HERE/policy/intent.json" 2>/dev/null || true)"
[[ -z "$DUTY" ]] && DUTY="INTENT chat prose before tools; tag edit:|NEW:; never Shell-declare."
PENDING=""
if [[ -s "$STATE/pending_files.md" ]]; then
  PENDING="PENDING_FILES (finish this turn, no drip): $(tr '\n' ' ' <"$STATE/pending_files.md")"
fi
OUTCOMES_CTX=""
[[ -s "$STATE/outcomes.md" ]] && OUTCOMES_CTX="OUTCOMES_DETECTED: $(cat "$STATE/outcomes.md") user outcome(s) → Done-when MUST list ≥ that many predicates (1 per outcome). Under-scoped Done-when is rejected."
if [[ "$ROUTE" == "code" ]]; then
  EPILOGUE="Codebase first: Read AGENTS.md/CLAUDE.md + manifest, Glob/Grep the feature area, THEN edit. Vault write-back at session END (Session+hot+HANDOFF) — NOT before tools."
elif [[ "$ROUTE" == "memory" ]]; then
  EPILOGUE="vault_read wiki/hot.md then wiki/index.md; end Session + hot + HANDOFF."
else
  EPILOGUE="Task-first. Vault write-back at session end (Session+hot+HANDOFF) if durable."
fi
jq -n --arg c "ROUTE_CLASSIFY: ${ROUTE}
DEBERES: ${DUTY}
FILE_MAP: ground Glob|Grep|Read → tag edit:path|NEW:path in chat INTENT → StrReplace existing; Write only NEW → re-Read tags → prove Done-when. Never echo INTENT into Shell.
${OUTCOMES_CTX}
${PENDING}
${EPILOGUE}" '{additional_context: $c}'
