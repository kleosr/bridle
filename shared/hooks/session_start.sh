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
[[ -z "$DUTY" ]] && DUTY="GROUND first (Grep/Glob/Read this codebase — do not invent paths). Then INTENT + OBJECTIVE + edit:|NEW: from hits. Write|StrReplace only tagged paths."
CTX="Session start. Order (steering, no deny):
1. GROUNDING — Read HANDOFF.md + AGENTS.md. Grep/Glob/Read THIS codebase for the user's request. Do not invent paths. Read every file you will tag.
2. JOB CARD — after hits, declare in chat (never Shell/fence) before Write:
INTENT: <one line>
OBJECTIVE=<postcondition on named units — what is true when done>
edit:path
NEW:path
Done-when:
- <decidable predicate>
Tags come from hits only. Then Write|StrReplace only tagged paths. Never Shell to write code.
DEBERES: ${DUTY}
HANDOFF tail:
${TAIL}"
emit_context "$CTX"
