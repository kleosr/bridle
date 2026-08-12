#!/usr/bin/env bash
source "$HERE/lib/stop_prose.sh"
source "$HERE/lib/culture_gate.sh"
source "$HERE/lib/stop_tiers.sh"
source "$HERE/lib/stop_fs.sh"

TAG_RE='(edit|NEW):[A-Za-z0-9_./+=-]+'
rules_tags() { printf '%s\n' "$PROSE" | grep -oE "$TAG_RE" | sed 's/^[^:]*://' | grep -vx 'path' || true; }

rules_follow() {
  mkdir -p "$STATE"
  printf '%s\n' "$PROSE" >"$STATE/pending_intent.md"
  rules_tags >"$STATE/pending_files.md" 2>/dev/null || true
  emit_followup "$1"; exit 0
}

tier0_accept() {
  [[ $(pe_stop_accepted) -eq 1 ]] && { emit_quiet; exit 0; }
  if [[ "$STATUS" == "completed" && "${MSG_N:-0}" -eq 0 && -z "$PROSE" ]]; then
    mkdir -p "$STATE"
    printf '%s | WARN | stop_gate empty turn (MSG_N=0, no PROSE) — fail open\n' \
      "$(date +%Y-%m-%d\ %H:%M:%S)" >>"$STATE/session.log" 2>/dev/null || true
    emit_quiet; exit 0
  fi
  return 0
}

tier1_structure() {
  if [[ $(pe_has_intent) -eq 0 || $(pe_has_done_when) -eq 0 ]]; then
    rules_follow "INTENT must be chat prose before tools (never fenced, never Shell). INTENT: OBJECTIVE=postcondition; tag edit:path|NEW:path; Done-when: ≤5 decidable predicates. Edits via Write|StrReplace only. Finish ALL tags this turn; Done-when: met; update HANDOFF."
  fi
  if ! printf '%s\n' "$PROSE" | grep -iqE 'OBJECTIVE[[:space:]]*[=:]'; then
    rules_follow "OBJECTIVE missing: state OBJECTIVE=<postcondition on named units> in chat INTENT (what is true when done), plus edit:|NEW: tags and Done-when predicates."
  fi
  local oq; oq="$(pe_objective_ok)"
  if [[ "$oq" == "weak" ]]; then
    rules_follow "OBJECTIVE too weak: must be a postcondition (≥20 chars) on named units — what is true when done. Not 'done'/'fixed'. Example: OBJECTIVE=src/auth.ts exports parseToken and tests/run.sh is green."
  fi
  if [[ "$oq" == "task" ]]; then
    rules_follow "OBJECTIVE is task-shaped (implement/add/fix the…). Rewrite as a postcondition: what is true when done, on named units."
  fi
  if ! rules_tags | grep -q .; then
    rules_follow "FILE_MAP missing in chat INTENT: tag every path as edit:path or NEW:path. Ground Glob/Grep/Read, then complete every tag this turn — no drip."
  fi
  if [[ -s "$STATE/allowed_files.md" ]]; then rules_topology; fi
  rules_writes_tagged
  local outcomes; outcomes="$(cat "$STATE/outcomes.md" 2>/dev/null || echo 1)"
  outcomes="${outcomes//[!0-9]}"; [[ -z "$outcomes" || "$outcomes" -lt 1 ]] && outcomes=1
  local dw_pred; dw_pred="$(pe_dw_pred_count)"
  if [[ "${dw_pred:-0}" -lt "$outcomes" ]]; then
    rules_follow "UNDER-SCOPE: ${outcomes} outcome(s) detected but Done-when lists only ${dw_pred:-0} predicate(s) — 1 decidable predicate per outcome. List ≥ ${outcomes} predicates under Done-when ('- ' or '1.' each), prove them, then Done-when: met."
  fi
  if [[ "${dw_pred:-0}" -gt 5 ]]; then
    rules_follow "Done-when roof: ≤5 decidable predicates (got ${dw_pred}). Keep only falsifiable checks; drop essay bullets."
  fi
  local ilines; ilines="$(pe_intent_body_lines)"
  local anch; anch="$(pe_anchor_count)"
  if [[ "${ilines:-0}" -gt "$MAX_BODY" || "${anch:-0}" -gt "$MAX_ANCH" ]]; then
    rules_follow "Thin INTENT roof: ≤${MAX_ANCH} anchors; ≤${MAX_BODY} body lines. Keep postcondition + tags + predicates; drop essay."
  fi
}

tier2_semantic() {
  local hit; hit="$(pe_semantic_hit)"
  [[ "$hit" == "ask" ]] && rules_follow "STOP REJECTED: permission ask. Complete every tagged FILE this turn via Write|StrReplace, then Done-when: met."
  [[ "$hit" == "drip" ]] && rules_follow "DRIP REJECTED: no multi-prompt drip. Connect every edit:|NEW: path now; prove Done-when; then met."
  if [[ $(pe_dw_met) -eq 0 ]]; then
    rules_follow "PREMATURE STOP: Done-when unmet in chat prose. Re-Read tagged FILES; prove every predicate; finish ALL tags this turn; write Done-when: met."
  fi
}

rules_run() { tier0_accept; tier1_structure; tier2_semantic; tier2_evidence; tier2_culture; tier2_legacy_split; tier3_fs; rules_accept; }
