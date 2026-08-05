#!/usr/bin/env bash
# hooks/lib/stop_gate_core.sh — stop gate logic (sourced by hooks/stop_gate.sh).
# Receives INPUT on stdin, emits followup_message or {} on stdout.
set -euo pipefail
HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$HERE/lib/common.sh"
resolve_root

STATE="$(state_dir)"; HANDOFF="$ROOT/HANDOFF.md"; POLICY="$HERE/policy/intent.json"
MAX_BODY="$(jq -r '.max_intent_body_lines // 6' "$POLICY" 2>/dev/null || echo 6)"
MAX_ANCH="$(jq -r '.max_named_anchors // 5' "$POLICY" 2>/dev/null || echo 5)"
INPUT="$(cat)"
STATUS="$(echo "$INPUT" | jq -r 'if .status == null then "" else .status end' 2>/dev/null || true)"
[[ -n "$STATUS" && "$STATUS" != "completed" ]] && { emit_quiet; exit 0; }
MSG_N="$(echo "$INPUT" | jq -r '((.messages // .transcript // .conversation // []) | if type=="array" then length else 0 end)' 2>/dev/null || echo 0)"
MSG_N="${MSG_N//[!0-9]}"
[[ -z "$MSG_N" ]] && MSG_N=0
TURN="$(echo "$INPUT" | jq -r '
  def to_text:
    if type == "array"
    then map(select((.type // "text") == "text") | (.text // .content // "")) | join("\n")
    else tostring end;
  ((.messages // .transcript // .conversation // []) | if type=="array" then . else [] end) as $arr
  | ([range(0; ($arr | length)) | select(
      (($arr[.].role // $arr[.].type // "") | test("user|human"; "i"))
      and (($arr[.].content // "") | type) == "string"
    )]) as $realUserIdxs
  | (if ($realUserIdxs | length) > 0 then ($realUserIdxs | last) + 1 else 0 end) as $start
  | [$arr[$start:][] | select((.role // .type // "") | test("assistant"; "i")) | ((.content // .text // "") | to_text)]
  | join("\n")' 2>/dev/null || true)"
[[ -z "$TURN" || "$TURN" == "null" ]] && TURN=""
PROSE="$(printf '%s\n' "$TURN" | awk 'BEGIN{f=0} /^```/{f=1-f;next} !f')"
TAG_RE='(edit|NEW):[A-Za-z0-9_./+=-]+'
tags() { echo "$PROSE" | grep -oE "$TAG_RE" | sed 's/^[^:]*://' | grep -vx 'path' || true; }
follow() {
  mkdir -p "$STATE"
  printf '%s\n' "$PROSE" >"$STATE/pending_intent.md"
  tags >"$STATE/pending_files.md" 2>/dev/null || true
  emit_followup "$1"; exit 0
}
echo "$PROSE" | grep -Fq 'STOP ACCEPTED' && { emit_quiet; exit 0; }
accept() {
  local date; date="$(date +%Y-%m-%d)"
  rm -rf "$STATE"; mkdir -p "$STATE"
  # Preserve prior history: carry previous ## Archived section content forward.
  # Strip any prior placeholder line — the template below always emits a fresh
  # one, so keeping the old one caused the placeholder to accumulate on every
  # accept cycle. The COMPACTION PROTOCOL comment is legitimate content; keep it.
  local archived=""
  if [[ -f "$HANDOFF" ]]; then
    # Dedupe: the placeholder line is always re-emitted by the template below,
    # so strip any prior copy from the archived content to avoid accumulation.
    archived="$(sed -n '/^## Archived/,$p' "$HANDOFF" 2>/dev/null | tail -n +2 \
      | grep -vxF '(Older context compacted here when active sections exceed ~150 lines.)' || true)"
  fi
  {
    echo "# HANDOFF — Session State"
    echo ""
    echo "## Active Objective"
    echo ""
    echo "Session complete ${date}"
    echo ""
    echo "## Current State"
    echo ""
    echo "Done-when: met. (agent fills details)"
    echo ""
    echo "## Next Actions"
    echo ""
    echo "Update HANDOFF with next session objective. Optional: Obsidian vault write-back if configured."
    echo ""
    echo "## Archived"
    echo ""
    if [[ -n "$archived" ]]; then
      echo "$archived"
      echo ""
    fi
    echo "(Older context compacted here when active sections exceed ~150 lines.)"
  } >"$HANDOFF"
  emit_quiet; exit 0
}
[[ "$STATUS" == "completed" && "${MSG_N:-0}" -eq 0 && -z "$PROSE" ]] && accept
echo "$PROSE" | grep -iqE '^[[:space:]]*INTENT:' && echo "$PROSE" | grep -iqE '^[[:space:]]*Done-when:' || follow "INTENT must be chat prose (first, before tools) — never Shell/Write/code-fence. INTENT: <OBJECTIVE=postcondition; tag edit:path|NEW:path>; Done-when: <≤5 decidable predicates>. Finish ALL tagged FILES this turn; Done-when: met; update HANDOFF."
tags | grep -q . || follow "FILE_MAP missing in chat INTENT: tag every path as edit:path or NEW:path. Ground Glob/Grep/Read, then complete every tag this turn — no drip across prompts."
if [[ -s "$STATE/allowed_files.md" ]]; then
  VIOLATIONS=""
  while IFS= read -r tag; do [[ -z "$tag" ]] && continue
    grep -qxF "$tag" "$STATE/allowed_files.md" || VIOLATIONS="$VIOLATIONS $tag"
  done < <(tags)
  [[ -n "$VIOLATIONS" ]] && follow "TOPOLOGY VIOLATION: Intentaste tocar un archivo fuera de tu FILE_MAP:$VIOLATIONS. Corrige tu INTENT — solo edita/crea paths que declaraste en tu FILE_MAP, o expande tu INTENT explícitamente."
fi
DW_PRED="$(echo "$PROSE" | awk 'tolower($0)~/^[[:space:]]*done-when:/{dw=1;next} dw&&/^[[:space:]]*[-•*][[:space:]]/{n++;next} dw&&/^[[:space:]]*[0-9]+[.)][[:space:]]/{n++;next} dw&&tolower($0)~/^(intent|objective|constraints|files|scope|risk):/{dw=0} END{print n+0}')"
OUTCOMES="$(cat "$STATE/outcomes.md" 2>/dev/null || echo 1)"
OUTCOMES="${OUTCOMES//[!0-9]}"
[[ -z "$OUTCOMES" || "$OUTCOMES" -lt 1 ]] && OUTCOMES=1
[[ "${DW_PRED:-0}" -eq 0 ]] && follow "UNDER-SCOPE: INTENT must list at least one Done-when predicate (on its own line prefixed with '- ' or '1.'). What must hold on disk/tools for this task to be done?"
ILINES="$(echo "$PROSE" | awk 'tolower($0)~/^[[:space:]]*intent:/{p=1;n=0;next} p&&tolower($0)~/^[[:space:]]*done-when:/{exit} p&&NF{n++} END{print n+0}')"
ANCH="$(echo "$PROSE" | grep -ciE '^[[:space:]]*(INTENT|OBJECTIVE|CONSTRAINTS|FILES|SCOPE|RISK):' || true)"
[[ "${ILINES:-0}" -gt "$MAX_BODY" || "${ANCH:-0}" -gt "$MAX_ANCH" ]] && follow "Thin INTENT roof: ≤${MAX_ANCH} anchors; ≤${MAX_BODY} body lines. Keep postcondition + tags + predicates; drop essay."
ASK_RE='(déjame saber|quieres que|puedo (hacer|agregar)|me avisas|debería agregar|let me know if|want me to|should I (add|also)|I can (add|also)|if you('\''|’)d like|if you want( me)? to|say if you want)'
echo "$PROSE" | grep -iqE "$ASK_RE" && follow "STOP REJECTED: permission ask. Complete every tagged FILE this turn, then Done-when: met."
echo "$PROSE" | grep -iqE '(next (pass|step|turn|iteration|phase)|will continue|partial(ly)?|remaining files|in a follow-?up|siguiente (pass|turno|paso|fase)|dejar[eé] para|pr[oó]xim[oa]|luego|m[aá]s tarde|subsequent|later|resto|handle the rest|proceed with the rest)' && follow "DRIP REJECTED: no multi-prompt drip. Connect every edit:|NEW: path now; prove Done-when; then met."
SESSION_TS=$(cat "$STATE/session_ts" 2>/dev/null || echo 0)
SESSION_TS="${SESSION_TS//[!0-9]}"
[[ -z "$SESSION_TS" ]] && SESSION_TS=0
UNTOUCHED=""
while IFS= read -r p; do [[ -z "$p" ]] && continue
  [[ "$p" = /* ]] && fp="$p" || fp="$(pwd)/$p"
  [[ -f "$fp" ]] || { UNTOUCHED="$UNTOUCHED $p(missing)"; continue; }
  fp_mtime="$(stat -c %Y "$fp" 2>/dev/null || echo 0)"
  fp_mtime="${fp_mtime//[!0-9]}"
  [[ -z "$fp_mtime" ]] && fp_mtime=0
  [[ "$SESSION_TS" -eq 0 || "$fp_mtime" -ge "$SESSION_TS" ]] || UNTOUCHED="$UNTOUCHED $p"
done < <(tags)
[[ -n "$UNTOUCHED" ]] && follow "FILES NOT TOUCHED:$UNTOUCHED — every tagged edit:|NEW: path must be written to disk this turn. Edit/write each file, then Done-when: met."
echo "$PROSE" | grep -iqE 'Done-when[[:space:]]*:[[:space:]]*(met|cumplido|complete|done)\b|✅[[:space:]]*Done-when[[:space:]]+met' || follow "PREMATURE STOP: Done-when unmet in chat prose. Re-Read tagged FILES; prove every predicate; finish ALL tags this turn; write Done-when: met."
# Compaction gate: if HANDOFF.md > 180 lines, force compaction before accept.
HANDOFF_LINES="$(wc -l < "$HANDOFF" 2>/dev/null || echo 0)"
HANDOFF_LINES="${HANDOFF_LINES//[!0-9]}"
[[ -z "$HANDOFF_LINES" ]] && HANDOFF_LINES=0
if [[ "$HANDOFF_LINES" -gt 180 ]]; then
  follow "HANDOFF.md is ${HANDOFF_LINES} lines (>180 roof). Compact: move older Recent Changes into Archived, compress Failed Attempts to one-liners. Keep active sections under 150 lines, then Done-when: met."
fi
accept
