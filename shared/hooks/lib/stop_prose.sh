#!/usr/bin/env bash
# Sourced by stop_rules.sh. Pure prose-pattern predicates.
# Each predicate echoes 1 (match) or 0 (no match) so callers can branch once.

pe_has_intent()    { printf '%s\n' "$PROSE" | grep -iqE '^[[:space:]]*INTENT:'    && echo 1 || echo 0; }
pe_has_done_when() { printf '%s\n' "$PROSE" | grep -iqE '^[[:space:]]*Done-when:' && echo 1 || echo 0; }
pe_stop_accepted() { printf '%s\n' "$PROSE" | grep -Fq 'STOP ACCEPTED'            && echo 1 || echo 0; }

pe_dw_met() {
  printf '%s\n' "$PROSE" | grep -iqE 'Done-when[[:space:]]*:[[:space:]]*(met|cumplido|complete|done)\b|✅[[:space:]]*Done-when[[:space:]]+met' \
    && echo 1 || echo 0
}

pe_dw_pred_count() {
  printf '%s\n' "$PROSE" | awk 'tolower($0)~/^[[:space:]]*done-when:/{dw=1;next} dw&&/^[[:space:]]*[-•*][[:space:]]/{n++;next} dw&&/^[[:space:]]*[0-9]+[.)][[:space:]]/{n++;next} dw&&tolower($0)~/^(intent|objective|constraints|files|scope|risk):/{dw=0} END{print n+0}'
}

pe_intent_body_lines() {
  printf '%s\n' "$PROSE" | awk 'tolower($0)~/^[[:space:]]*intent:/{p=1;n=0;next} p&&tolower($0)~/^[[:space:]]*done-when:/{exit} p&&NF{n++} END{print n+0}'
}

pe_anchor_count() {
  printf '%s\n' "$PROSE" | grep -ciE '^[[:space:]]*(INTENT|OBJECTIVE|CONSTRAINTS|FILES|SCOPE|RISK):' || true
}

SEM_ASK_RE='(déjame saber|quieres que|puedo (hacer|agregar)|me avisas|debería agregar|let me know if|want me to|should I (add|also)|I can (add|also)|if you('\''|’)d like|if you want( me)? to|say if you want)'
SEM_DRIP_RE='(next (pass|step|turn|iteration|phase)|will continue|partial(ly)?|remaining files|in a follow-?up|siguiente (pass|turno|paso|fase)|dejar[eé] para|pr[oó]xim[oa]|luego|m[aá]s tarde|subsequent|later|resto|handle the rest|proceed with the rest)'

pe_semantic_hit() {
  local hit
  hit="$(printf '%s\n' "$PROSE" | grep -ioE "$SEM_ASK_RE|$SEM_DRIP_RE" | head -n 1 || true)"
  [[ -z "$hit" ]] && return 0
  if printf '%s' "$hit" | grep -iqE "$SEM_ASK_RE"; then echo ask; else echo drip; fi
}
