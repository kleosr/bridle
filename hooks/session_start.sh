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
HANDOFF="$ROOT/HANDOFF.md"
TAIL=""
if [[ -f "$HANDOFF" ]]; then
  TAIL="$(tail -n 15 "$HANDOFF")"
fi
CTX="AMNESIA: vault survives. vault_read wiki/hot.md then wiki/index.md. INTENT job card: OBJECTIVE=postcondition on named units; ground Glob/Grep/Read → tag paths; Done-when=≤5 decidable predicates. HANDOFF tail:
${TAIL}"
jq -n --arg c "$CTX" '{additional_context: $c}'
