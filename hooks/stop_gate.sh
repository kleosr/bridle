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
STATE="$ROOT/state"; HANDOFF="$ROOT/HANDOFF.md"; POLICY="$HERE/policy/intent.json"
MAX_BODY="$(jq -r '.max_intent_body_lines // 6' "$POLICY" 2>/dev/null || echo 6)"
MAX_ANCH="$(jq -r '.max_named_anchors // 5' "$POLICY" 2>/dev/null || echo 5)"
INPUT="$(cat)"
STATUS="$(echo "$INPUT" | jq -r 'if .status == null then "" else .status end' 2>/dev/null || true)"
[[ -n "$STATUS" && "$STATUS" != "completed" ]] && { echo '{}'; exit 0; }
LOOP="$(echo "$INPUT" | jq -r '.loop_count // .loopCount // 0' 2>/dev/null || echo 0)"
MSG_N="$(echo "$INPUT" | jq -r '((.messages // .transcript // .conversation // []) | if type=="array" then length else 0 end)' 2>/dev/null || echo 0)"
LAST="$(echo "$INPUT" | jq -r '
  ((.messages // .transcript // .conversation // []) | if type=="array" then . else [] end)
  | map(select((.role // .type // "") | test("assistant"; "i"))) | last
  | if . == null then "" else
      (.content // .text // "")
      | if type=="array" then map(select((.type // "text") == "text") | (.text // .content // "")) | join("\n")
        else tostring end
    end' 2>/dev/null || true)"
[[ -z "$LAST" || "$LAST" == "null" ]] && LAST=""
PROSE="$(printf '%s\n' "$LAST" | awk 'BEGIN{f=0} /^```/{f=1-f;next} !f')"
follow() {
  mkdir -p "$STATE"
  printf '%s\n' "$PROSE" >"$STATE/pending_intent.md"
  echo "$PROSE" | grep -oE '(edit|NEW):[^[:space:]]+' >"$STATE/pending_files.md" 2>/dev/null || true
  jq -n --arg m "$1" '{followup_message: $m}'; exit 0
}
quiet() { echo '{}'; exit 0; }
echo "$PROSE" | grep -Fq 'STOP ACCEPTED' && quiet
accept() {
  local date; date="$(date +%Y-%m-%d)"
  rm -rf "$STATE"; mkdir -p "$STATE"
  cat >"$HANDOFF" <<EOF
TASK
Session complete ${date}

FILES
(agent fills)

STATUS
Done-when: met

NEXT
vault_write Session + refresh hot + mirror HANDOFF.md
EOF
  [[ "${LOOP:-0}" -ge 1 ]] && quiet
  jq -n --arg m "STOP ACCEPTED. Obsidian write-back: vault_write wiki/projects/<slug>/Sessions/${date}-topic.md COMPLETE (Goal Done-when Residual LAYER CHECK) + refresh wiki/hot.md + mirror HANDOFF.md. Close with Done-when: met if not already written." '{followup_message: $m}'
  exit 0
}
[[ "${MSG_N:-0}" -eq 0 && -z "$PROSE" ]] && accept
echo "$PROSE" | grep -qE '^[[:space:]]*INTENT:' && echo "$PROSE" | grep -qE '^[[:space:]]*Done-when:' || follow "INTENT must be chat prose (first, before tools) — never Shell/Write/code-fence. INTENT: <OBJECTIVE=postcondition; tag edit:path|NEW:path>; Done-when: <≤5 decidable predicates>. Finish ALL tagged FILES this turn; Done-when: met; Session+hot+HANDOFF."
echo "$PROSE" | grep -qE '(edit|NEW):[^[:space:]]+' || follow "FILE_MAP missing in chat INTENT: tag every path as edit:path or NEW:path. Ground Glob/Grep/Read, then complete every tag this turn — no drip across prompts."
DW_PRED="$(echo "$PROSE" | awk '/^[[:space:]]*Done-when:/{dw=1;next} dw&&/^[[:space:]]*[-•*][[:space:]]/{n++;next} dw&&/^[[:space:]]*[0-9]+[.)][[:space:]]/{n++;next} dw&&/^(INTENT|OBJECTIVE|CONSTRAINTS|FILES|SCOPE|RISK):/{dw=0} END{print n+0}')"
OUTCOMES="$(cat "$STATE/outcomes.md" 2>/dev/null || echo 1)"
[[ "$OUTCOMES" -lt 1 ]] && OUTCOMES=1
[[ "${DW_PRED:-0}" -lt "$OUTCOMES" ]] && follow "UNDER-SCOPE: user ask has $OUTCOMES outcome(s) but INTENT declares only $DW_PRED Done-when predicate(s). Need ≥$OUTCOMES — one predicate per outcome, each on its own line prefixed with '- ' or '1.'. Expand Done-when: what does the ask require beyond what you tagged?"
ILINES="$(echo "$PROSE" | awk '/^[[:space:]]*INTENT:/{p=1;n=0;next} p&&/^[[:space:]]*Done-when:/{exit} p&&NF{n++} END{print n+0}')"
ANCH="$(echo "$PROSE" | grep -ciE '^[[:space:]]*(INTENT|OBJECTIVE|CONSTRAINTS|FILES|SCOPE|RISK):' || true)"
[[ "${ILINES:-0}" -gt "$MAX_BODY" || "${ANCH:-0}" -gt "$MAX_ANCH" ]] && follow "Thin INTENT roof: ≤${MAX_ANCH} anchors; ≤${MAX_BODY} body lines. Keep postcondition + tags + predicates; drop essay."
ASK_RE='(déjame saber|quieres que|puedo (hacer|agregar)|me avisas|debería agregar|let me know if|want me to|should I (add|also)|I can (add|also)|if you('\''|’)d like|if you want( me)? to|say if you want)'
echo "$PROSE" | grep -iqE "$ASK_RE" && follow "STOP REJECTED: permission ask. Complete every tagged FILE this turn, then Done-when: met."
echo "$PROSE" | grep -iqE '(next pass|will continue|partial(ly)?|remaining files|in a follow-?up|siguiente (pass|turno)|dejar[eé] para)' && follow "DRIP REJECTED: no multi-prompt drip. Connect every edit:|NEW: path now; prove Done-when; then met."
SESSION_TS=$(cat "$STATE/session_ts" 2>/dev/null || echo 0)
UNTOUCHED=""
while IFS= read -r p; do [[ -z "$p" ]] && continue
  [[ "$p" = /* ]] && fp="$p" || fp="$(pwd)/$p"
  [[ -f "$fp" ]] || { UNTOUCHED="$UNTOUCHED $p(missing)"; continue; }
  [[ "$SESSION_TS" -eq 0 || "$(stat -c %Y "$fp" 2>/dev/null || echo 0)" -ge "$SESSION_TS" ]] || UNTOUCHED="$UNTOUCHED $p"
done < <(echo "$PROSE" | grep -oE '(edit|NEW):[^[:space:]]+' | sed 's/^[^:]*://' || true)
[[ -n "$UNTOUCHED" ]] && follow "FILES NOT TOUCHED:$UNTOUCHED — every tagged edit:|NEW: path must be written to disk this turn. Edit/write each file, then Done-when: met."
echo "$PROSE" | grep -iqE 'Done-when[[:space:]]*:[[:space:]]*(met|cumplido|complete|done)\b|✅[[:space:]]*Done-when[[:space:]]+met' || follow "PREMATURE STOP: Done-when unmet in chat prose. Re-Read tagged FILES; prove every predicate; finish ALL tags this turn; write Done-when: met."
accept
