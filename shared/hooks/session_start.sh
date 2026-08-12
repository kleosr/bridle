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
[[ -z "$DUTY" ]] && DUTY="INTENT chat prose before tools; OBJECTIVE=<postcondition>; tag edit:|NEW:; Write|StrReplace only."
CTX="Session start. GROUNDING (before any Write/StrReplace — steering, no deny):
1. Read HANDOFF.md tail + AGENTS.md
2. Grep/Glob/Read THIS codebase for the feature (reuse before write)
3. Read each file you will tag
JOB CARD — declare in chat prose before tools (never Shell/fence):
INTENT: <one line>
OBJECTIVE=<postcondition on named units — what is true when done>
edit:path
NEW:path
Done-when:
- <decidable predicate>
Then Write|StrReplace only tagged paths. Never Shell to write code.
DEBERES: ${DUTY}
HANDOFF tail:
${TAIL}"
emit_context "$CTX"
