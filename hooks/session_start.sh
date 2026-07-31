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
CTX="Session start. INTENT = chat prose before tools (never Shell). Tag edit:|NEW:; finish all tags this turn. For CODE work: ground in codebase first (AGENTS.md, Glob/Grep, manifest) — vault write-back at session END. HANDOFF tail:
${TAIL}"
jq -n --arg c "$CTX" '{additional_context: $c}'
