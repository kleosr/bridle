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
[[ -z "$DUTY" ]] && DUTY="INTENT job card: OBJECTIVE=postcondition on named units (tag paths); CONSTRAINTS=≤2 invariants; Done-when=≤5 decidable predicates. Ground Glob/Grep/Read; StrReplace existing; Write NEW only."
jq -n --arg c "ROUTE_CLASSIFY: ${ROUTE}
DEBERES: ${DUTY}
FILE_MAP: ground Glob|Grep|Read → tag edit:path|NEW:path in OBJECTIVE → StrReplace existing; Write only NEW → follow-up re-Read tagged FILES then prove Done-when.
Amnesia: vault_read wiki/hot.md then wiki/index.md; end Session wiki/projects/<slug>/Sessions/YYYY-MM-DD-topic + hot." '{additional_context: $c}'
