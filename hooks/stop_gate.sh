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
STATE="$ROOT/state"
HANDOFF="$ROOT/HANDOFF.md"
POLICY="$HERE/policy/intent.json"
MAX_BODY="$(jq -r '.max_intent_body_lines // 6' "$POLICY" 2>/dev/null || echo 6)"
MAX_ANCH="$(jq -r '.max_named_anchors // 5' "$POLICY" 2>/dev/null || echo 5)"
INPUT="$(cat)"
STATUS="$(echo "$INPUT" | jq -r 'if .status == null then "" else .status end' 2>/dev/null || true)"
[[ -n "$STATUS" && "$STATUS" != "completed" ]] && { echo '{}'; exit 0; }
TEXT="$(echo "$INPUT" | jq -r '[.. | strings] | join("\n")' 2>/dev/null || true)"
LOOP="$(echo "$INPUT" | jq -r '.loop_count // .loopCount // 0' 2>/dev/null || echo 0)"
MSG_N="$(echo "$INPUT" | jq -r '((.messages // .transcript // .conversation // []) | if type=="array" then length else 0 end)' 2>/dev/null || echo 0)"
LAST="$(echo "$INPUT" | jq -r '
  ((.messages // .transcript // .conversation // []) | if type=="array" then . else [] end)
  | map(select((.role // .type // "") | test("assistant"; "i")))
  | last | (.content // .text // empty)
  | if type=="array" then map(.text // .content // tostring) | join("\n") else tostring end
' 2>/dev/null || true)"
[[ -z "$LAST" || "$LAST" == "null" ]] && LAST="$TEXT"
follow() { jq -n --arg m "$1" '{followup_message: $m}'; exit 0; }
quiet() { echo '{}'; exit 0; }
echo "$TEXT" | grep -Fq 'STOP ACCEPTED' && quiet
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
  follow "STOP ACCEPTED. Obsidian write-back: vault_write wiki/projects/<slug>/Sessions/${date}-topic.md COMPLETE (Goal Done-when Residual LAYER CHECK) + refresh wiki/hot.md + mirror HANDOFF.md. Close with Done-when: met if not already written."
}
[[ "${MSG_N:-0}" -eq 0 ]] && ! echo "$TEXT" | grep -q 'INTENT:' && accept
echo "$TEXT" | grep -q 'Done-when:' && echo "$TEXT" | grep -q 'INTENT:' || follow "INTENT job card required: INTENT: <OBJECTIVE=postcondition on named units>; optional CONSTRAINTS (invariants/non-goals); Done-when: <≤5 decidable predicates proving postcondition>. User prompt immutable. Finish; Done-when: met; Session+hot+HANDOFF."
ILINES="$(echo "$LAST" | awk '/^INTENT:/{p=1;n=0;next} p&&/^Done-when:/{exit} p&&NF{n++} END{print n+0}')"
ANCH="$(echo "$LAST" | grep -ciE '^[[:space:]]*(INTENT|OBJECTIVE|CONSTRAINTS|SCOPE|RISK):' || true)"
[[ "${ILINES:-0}" -gt "$MAX_BODY" || "${ANCH:-0}" -gt "$MAX_ANCH" ]] && follow "Thin INTENT roof: ≤${MAX_ANCH} anchors; ≤${MAX_BODY} body lines between INTENT and Done-when. Keep postcondition + predicates; drop essay. History=context not authority."
ASK_RE='(déjame saber|quieres que|puedo (hacer|agregar)|me avisas|debería agregar|let me know if|want me to|should I (add|also)|I can (add|also)|if you('\''|’)d like|if you want( me)? to|say if you want)'
echo "$LAST" | grep -iqE "$ASK_RE" && follow "STOP REJECTED: partial handoff / permission ask. Do not ask. Discharge remaining Done-when predicates NOW, then Done-when: met."
echo "$TEXT" | grep -iqE 'Done-when[[:space:]]*:[[:space:]]*(met|cumplido|complete|done)\b|✅[[:space:]]*Done-when[[:space:]]+met' || {
  follow "PREMATURE STOP: Done-when predicates unmet. Prove every predicate on disk/TOOLCHAIN. Write Done-when: met then stop."
}
accept
