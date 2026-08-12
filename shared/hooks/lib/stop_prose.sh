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

pe_objective_body() {
  printf '%s\n' "$PROSE" | awk '
    tolower($0) ~ /^[[:space:]]*objective[[:space:]]*[=:]/ {
      sub(/^[[:space:]]*[Oo][Bb][Jj][Ee][Cc][Tt][Ii][Vv][Ee][[:space:]]*[=:][[:space:]]*/, "")
      print
      exit
    }'
}

pe_objective_ok() {
  local body
  body="$(pe_objective_body)"
  body="$(printf '%s' "$body" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/  */ /g')"
  if [[ ${#body} -lt 20 ]]; then
    printf 'weak'; return 0
  fi
  if printf '%s' "$body" | grep -qiE '^(done|fixed|ok|complete|listo|hecho|finish(ed)?)\.?$'; then
    printf 'weak'; return 0
  fi
  if printf '%s' "$body" | grep -qiE '^(i will|i am going|vamos a|voy a|implement(ar)?|add |create |make |fix the|update the|refactor )\b'; then
    printf 'task'; return 0
  fi
  printf 'ok'
}

SEM_ASK_RE='(déjame saber|quieres que|puedo (hacer|agregar)|me avisas|debería agregar|let me know if|want me to|should I (add|also)|I can (add|also)|if you('\''|’)d like|if you want( me)? to|say if you want)'
SEM_DRIP_RE='(next (pass|step|turn|iteration|phase)|will continue|partial(ly)?|remaining files|in a follow-?up|siguiente (pass|turno|paso|fase)|dejar[eé] para|pr[oó]xim[oa]|luego|m[aá]s tarde|subsequent|later|resto|handle the rest|proceed with the rest)'

pe_semantic_hit() {
  local hit
  hit="$(printf '%s\n' "$PROSE" | grep -ioE "$SEM_ASK_RE|$SEM_DRIP_RE" | head -n 1 || true)"
  [[ -z "$hit" ]] && return 0
  if printf '%s' "$hit" | grep -iqE "$SEM_ASK_RE"; then echo ask; else echo drip; fi
}

# 1 = has TOOLCHAIN/test green signal in prose or session.log; 0 = none; empty/ambiguous handled by caller.
pe_has_verify_evidence() {
  if printf '%s\n' "$PROSE" | grep -qiE '(TOOLCHAIN|tests/run\.sh|scripts/doctor|npm test|pnpm test|pytest|cargo test).{0,60}(pass|green|ok|✓|FAIL: 0)|ALL CHECKS PASSED|PASS:[[:space:]]*[0-9]+'; then
    echo 1; return 0
  fi
  if [[ -n "${STATE:-}" && -f "$STATE/session.log" ]]; then
    if grep -qiE 'SHELL.*(VERIFY|GREEN)|(tests/run\.sh|scripts/doctor|npm test|pnpm test).*(PASS|GREEN|FAIL: 0)|ALL CHECKS PASSED' "$STATE/session.log" 2>/dev/null; then
      echo 1; return 0
    fi
  fi
  echo 0
}
