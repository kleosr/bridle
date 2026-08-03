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
MSG_N="$(echo "$INPUT" | jq -r '((.messages // .transcript // .conversation // []) | if type=="array" then length else 0 end)' 2>/dev/null || echo 0)"
# Claim 1 fix: scan the ENTIRE assistant turn (from the last real human message to end),
# not just the final assistant message. The LLM states INTENT at turn start, works,
# then finishes with a natural summary — the old $LAST-only check missed the INTENT.
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
# LAST = final assistant message only (used for file-mtime checks and STOP ACCEPTED)
LAST="$(echo "$INPUT" | jq -r '
  ((.messages // .transcript // .conversation // []) | if type=="array" then . else [] end)
  | map(select((.role // .type // "") | test("assistant"; "i"))) | last
  | if . == null then "" else
      (.content // .text // "")
      | if type=="array" then map(select((.type // "text") == "text") | (.text // .content // "")) | join("\n")
        else tostring end
    end' 2>/dev/null || true)"
[[ -z "$LAST" || "$LAST" == "null" ]] && LAST=""
# PROSE = code-fence-stripped full turn (formatting checks scan the whole turn)
PROSE="$(printf '%s\n' "$TURN" | awk 'BEGIN{f=0} /^```/{f=1-f;next} !f')"
TAG_RE='(edit|NEW):[A-Za-z0-9_./+=-]+'
tags() { echo "$PROSE" | grep -oE "$TAG_RE" | sed 's/^[^:]*://' | grep -vx 'path' || true; }
follow() {
  mkdir -p "$STATE"
  printf '%s\n' "$PROSE" >"$STATE/pending_intent.md"
  tags >"$STATE/pending_files.md" 2>/dev/null || true
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
  quiet
}
[[ "$STATUS" == "completed" && "${MSG_N:-0}" -eq 0 && -z "$PROSE" ]] && accept
echo "$PROSE" | grep -iqE '^[[:space:]]*INTENT:' && echo "$PROSE" | grep -iqE '^[[:space:]]*Done-when:' || follow "INTENT must be chat prose (first, before tools) — never Shell/Write/code-fence. INTENT: <OBJECTIVE=postcondition; tag edit:path|NEW:path>; Done-when: <≤5 decidable predicates>. Finish ALL tagged FILES this turn; Done-when: met; Session+hot+HANDOFF."
tags | grep -q . || follow "FILE_MAP missing in chat INTENT: tag every path as edit:path or NEW:path. Ground Glob/Grep/Read, then complete every tag this turn — no drip across prompts."
# Sandbox topology check: compare agent's tagged files against the allowed set
# snapshotted by before_submit_prompt from the user's original prompt. If the
# agent introduces a path not in the allowed set, reject with TOPOLOGY VIOLATION.
# Empty allowed_files.md = sandbox not seeded (user prompt had no paths) → skip.
if [[ -s "$STATE/allowed_files.md" ]]; then
  VIOLATIONS=""
  while IFS= read -r tag; do [[ -z "$tag" ]] && continue
    grep -qxF "$tag" "$STATE/allowed_files.md" || VIOLATIONS="$VIOLATIONS $tag"
  done < <(tags)
  [[ -n "$VIOLATIONS" ]] && follow "TOPOLOGY VIOLATION: Intentaste tocar un archivo fuera de tu FILE_MAP:$VIOLATIONS. Corrige tu INTENT — solo edita/crea paths que declaraste en tu FILE_MAP, o expande tu INTENT explícitamente."
fi
DW_PRED="$(echo "$PROSE" | awk 'tolower($0)~/^[[:space:]]*done-when:/{dw=1;next} dw&&/^[[:space:]]*[-•*][[:space:]]/{n++;next} dw&&/^[[:space:]]*[0-9]+[.)][[:space:]]/{n++;next} dw&&tolower($0)~/^(intent|objective|constraints|files|scope|risk):/{dw=0} END{print n+0}')"
# Claim 4 fix: the old strict `DW_PRED < OUTCOMES` comparison caused false rejections
# because LLMs are poor at 1:1 verb↔predicate counting. The before_submit_prompt hook
# already nudges the LLM with OUTCOMES_DETECTED context, so the count mismatch is
# advisory. stop_gate now only hard-rejects when Done-when has ZERO predicates; a
# present-but-thin list is accepted (line 58 already guarantees Done-when exists).
OUTCOMES="$(cat "$STATE/outcomes.md" 2>/dev/null || echo 1)"
[[ "$OUTCOMES" -lt 1 ]] && OUTCOMES=1
[[ "${DW_PRED:-0}" -eq 0 ]] && follow "UNDER-SCOPE: INTENT must list at least one Done-when predicate (on its own line prefixed with '- ' or '1.'). What must hold on disk/tools for this task to be done?"
ILINES="$(echo "$PROSE" | awk 'tolower($0)~/^[[:space:]]*intent:/{p=1;n=0;next} p&&tolower($0)~/^[[:space:]]*done-when:/{exit} p&&NF{n++} END{print n+0}')"
ANCH="$(echo "$PROSE" | grep -ciE '^[[:space:]]*(INTENT|OBJECTIVE|CONSTRAINTS|FILES|SCOPE|RISK):' || true)"
[[ "${ILINES:-0}" -gt "$MAX_BODY" || "${ANCH:-0}" -gt "$MAX_ANCH" ]] && follow "Thin INTENT roof: ≤${MAX_ANCH} anchors; ≤${MAX_BODY} body lines. Keep postcondition + tags + predicates; drop essay."
ASK_RE='(déjame saber|quieres que|puedo (hacer|agregar)|me avisas|debería agregar|let me know if|want me to|should I (add|also)|I can (add|also)|if you('\''|’)d like|if you want( me)? to|say if you want)'
echo "$PROSE" | grep -iqE "$ASK_RE" && follow "STOP REJECTED: permission ask. Complete every tagged FILE this turn, then Done-when: met."
# Claim 2 fix: broadened DRIP regex to catch common LLM synonyms for "defer to later"
# that the old narrow regex missed (next step, later, subsequent, proximamente, resto, etc.)
echo "$PROSE" | grep -iqE '(next (pass|step|turn|iteration|phase)|will continue|partial(ly)?|remaining files|in a follow-?up|siguiente (pass|turno|paso|fase)|dejar[eé] para|pr[oó]xim[oa]|luego|m[aá]s tarde|subsequent|later|resto|handle the rest|proceed with the rest)' && follow "DRIP REJECTED: no multi-prompt drip. Connect every edit:|NEW: path now; prove Done-when; then met."
SESSION_TS=$(cat "$STATE/session_ts" 2>/dev/null || echo 0)
UNTOUCHED=""
while IFS= read -r p; do [[ -z "$p" ]] && continue
  [[ "$p" = /* ]] && fp="$p" || fp="$(pwd)/$p"
  [[ -f "$fp" ]] || { UNTOUCHED="$UNTOUCHED $p(missing)"; continue; }
  [[ "$SESSION_TS" -eq 0 || "$(stat -c %Y "$fp" 2>/dev/null || echo 0)" -ge "$SESSION_TS" ]] || UNTOUCHED="$UNTOUCHED $p"
done < <(tags)
[[ -n "$UNTOUCHED" ]] && follow "FILES NOT TOUCHED:$UNTOUCHED — every tagged edit:|NEW: path must be written to disk this turn. Edit/write each file, then Done-when: met."
echo "$PROSE" | grep -iqE 'Done-when[[:space:]]*:[[:space:]]*(met|cumplido|complete|done)\b|✅[[:space:]]*Done-when[[:space:]]+met' || follow "PREMATURE STOP: Done-when unmet in chat prose. Re-Read tagged FILES; prove every predicate; finish ALL tags this turn; write Done-when: met."
accept
