#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
resolve_root
HANDOFF="$ROOT/HANDOFF.md"
TAIL=""
if [[ -f "$HANDOFF" ]]; then
  TAIL="$(tail -n 15 "$HANDOFF")"
fi
CTX="Session start. INTENT = chat prose before tools (never Shell). Tag edit:|NEW:; finish all tags this turn. For CODE work: ground in codebase first (AGENTS.md, Glob/Grep, manifest) — update HANDOFF at session END. HANDOFF tail:
${TAIL}"
emit_context "$CTX"
