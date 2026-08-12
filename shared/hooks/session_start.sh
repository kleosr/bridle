#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
mkdir -p "$STATE"
MODE="$(echo "$INPUT" | jq -r '.composer_mode // empty' 2>/dev/null || true)"
[[ -z "$MODE" ]] && MODE="agent"
printf '%s\n' "$MODE" >"$STATE/mode"
if [[ "$MODE" != "agent" ]]; then
  emit_quiet; exit 0
fi
HANDOFF="$ROOT/HANDOFF.md"
TAIL=""
if [[ -f "$HANDOFF" ]]; then
  TAIL="$(tail -n 40 "$HANDOFF" | sed -n '/<!-- COMPACTION PROTOCOL/,$d;p' | tail -n 15)"
fi
DUTY="$(jq -r '.duty // empty' "$HERE/policy/intent.json" 2>/dev/null || true)"
[[ -z "$DUTY" ]] && DUTY="INTENT chat prose before tools; OBJECTIVE=<postcondition>; tag edit:|NEW:; Write|StrReplace only — never Shell to write code. >700 LOC = rewrite modules + imports."
CTX="Session start. GROUNDING (antes del primer Write/StrReplace — steering only, no deny):
1. Read HANDOFF.md tail
2. Read AGENTS.md (o AGENTS del proyecto) + FILE_MAP / module map
3. Identify files to touch; Read each before Write/StrReplace
DEBERES: ${DUTY}
FILE_MAP: ground Glob|Grep|Read → tag edit:path|NEW:path in chat INTENT → Write|StrReplace → re-Read tags → prove Done-when. Never Shell to write code.
HANDOFF tail:
${TAIL}"
emit_context "$CTX"
