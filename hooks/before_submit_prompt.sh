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
INPUT="$(cat)"
PROMPT="$(echo "$INPUT" | jq -r '.prompt // .user_prompt // .message // .text // empty' 2>/dev/null || true)"
ROUTE="other"
echo "$PROMPT" | grep -qiE 'implement|fix|refactor|bug|code|patch|cargo|typescript|rust|bash' && ROUTE="code"
echo "$PROMPT" | grep -qiE 'remember|vault|obsidian|handoff|amnesia|session' && ROUTE="memory"
printf '%s\n' "$PROMPT" >"$STATE/current_intent.md"
DUTY="$(jq -r '.duty // empty' "$HERE/policy/intent.json" 2>/dev/null || true)"
[[ -z "$DUTY" ]] && DUTY="INTENT chat prose before tools; tag edit:|NEW:; never Shell-declare."
PENDING=""
if [[ -s "$STATE/pending_files.md" ]]; then
  PENDING="PENDING_FILES (finish this turn, no drip): $(tr '\n' ' ' <"$STATE/pending_files.md")"
fi
jq -n --arg c "ROUTE_CLASSIFY: ${ROUTE}
DEBERES: ${DUTY}
FILE_MAP: ground Glob|Grep|Read → tag edit:path|NEW:path in chat INTENT → StrReplace existing; Write only NEW → re-Read tags → prove Done-when. Never echo INTENT into Shell.
${PENDING}
Amnesia: vault_read wiki/hot.md then wiki/index.md; end Session + hot + HANDOFF." '{additional_context: $c}'
