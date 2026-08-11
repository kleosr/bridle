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
[[ -z "$DUTY" ]] && DUTY="INTENT chat prose before tools; tag edit:|NEW:; never Shell-declare."
PONYTAIL="$(jq -r '.ponytail_ladder // empty' "$HERE/policy/intent.json" 2>/dev/null || true)"
SOFT="$(jq -r '.file_loc_soft // 150' "$HERE/policy/lean.json" 2>/dev/null || echo 150)"
# beforeSubmitPrompt cannot inject context (continue only). Sticky duties live here.
CTX="Session start. DEBERES: ${DUTY}
FILE_MAP: ground Glob|Grep|Read → tag edit:path|NEW:path in chat INTENT → Write (create/overwrite) → re-Read tags → prove Done-when. Never echo INTENT into Shell.
SANDBOX: paths in your prompt snapshot to state/allowed_files.md. Writes outside warn at edit time; stop_gate audits every tagged file.
CONSTRAINTS: zero prose comments (lean_gate comment_ratio_max=2); soft LOC ${SOFT} (agent_message warn); hard 700 deny; 15 edits/file.
${PONYTAIL}
Codebase first: Read AGENTS.md + manifest, Glob/Grep the feature area, THEN edit. Update HANDOFF at session END — NOT before tools.
HANDOFF tail:
${TAIL}"
emit_context "$CTX"
