#!/usr/bin/env bash
# Bytes the pack contributes to a request. Provider usage (cached input,
# uncached input, output) is not visible to these hooks, so this does not
# invent a price. Tokens are bytes/4, a rough stand-in, not a model tokenizer.
# Optional: bash scripts/context_cost.sh /path/to/kleos-hooks.log
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
LOG="${1:-}"

bytes() { wc -c < "$1" | tr -d ' '; }

front_bytes() {
  awk 'BEGIN{c=0} /^---$/{c++; if (c==2) exit; next} c==1 {print}' "$1" | wc -c | tr -d ' '
}

div4() {
  local n="$1"
  printf '%s' $(( (n + 3) / 4 ))
}

sum_front() {
  local total=0 f n
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    n="$(front_bytes "$f")"
    total=$((total + n))
  done
  printf '%s' "$total"
}

CHARTER="$(bytes "$PACK/shared/rules/charter.txt")"
CORE="$(bytes "$PACK/shared/rules/core.mdc")"
TESTING="$(bytes "$PACK/shared/rules/testing.mdc")"
ALWAYS=$((CHARTER + CORE + TESTING))
AGENTS="$(bytes "$PACK/AGENTS.md")"
CATALOG="$(sum_front "$PACK"/shared/skills/*/SKILL.md)"
AGENT_DESC="$(sum_front "$PACK"/shared/agents/*.md)"
COMPANION=0
for f in "$PACK"/shared/rules/*.mdc; do
  base="$(basename "$f")"
  [[ "$base" == "core.mdc" || "$base" == "testing.mdc" ]] && continue
  COMPANION=$((COMPANION + $(bytes "$f")))
done

VOLATILE="$(grep -nE '\$\(|\$\{|20[0-9]{2}-[0-9]{2}-[0-9]{2}' \
  "$PACK/shared/rules/charter.txt" "$PACK/shared/rules/core.mdc" "$PACK/shared/rules/testing.mdc" || true)"

printf '%s\n' "always_on_bytes: $ALWAYS"
printf '%s\n' "always_on_tokens_div4: $(div4 "$ALWAYS")"
printf '%s\n' "charter_bytes: $CHARTER"
printf '%s\n' "core_bytes: $CORE"
printf '%s\n' "testing_bytes: $TESTING"
printf '%s\n' "agents_md_bytes: $AGENTS"
printf '%s\n' "catalog_description_bytes: $CATALOG"
printf '%s\n' "agent_description_bytes: $AGENT_DESC"
printf '%s\n' "companion_bytes: $COMPANION"
if [[ -z "$VOLATILE" ]]; then
  printf '%s\n' "volatile: none"
else
  printf '%s\n' "volatile: hit"
  printf '%s\n' "$VOLATILE"
fi
printf '%s\n' "billing: unmeasured"

if [[ -z "$LOG" ]]; then
  exit 0
fi
if [[ ! -f "$LOG" ]]; then
  printf '%s\n' "hook_log: absent"
  exit 0
fi
awk '
  {
    hook=""
    if (match($0, /\[[^]]+\]/)) hook = substr($0, RSTART+1, RLENGTH-2)
    exitc = ""
    if (match($0, /exit=[^ ]+/)) exitc = substr($0, RSTART+5, RLENGTH-5)
    stdout = ""
    if (match($0, /stdout=[0-9]+B/)) stdout = substr($0, RSTART+7, RLENGTH-8)
    verdict = ""
    if (match($0, /verdict=[^ ]+/)) verdict = substr($0, RSTART, RLENGTH)
    if (hook == "") next
    hooks[hook]++
    if (exitc != "" && exitc != "0") bad[hook]++
    if (stdout == "0") empty[hook]++
    if (verdict ~ /^verdict=deny/) deny[hook]++
    if (verdict ~ /^verdict=ask/) ask[hook]++
    if (verdict ~ /^verdict=followup/) follow[hook]++
  }
  END {
    print "hook_log: present"
    for (h in hooks) printf "hook %s %d\n", h, hooks[h]
    for (h in bad) printf "nonzero %s %d\n", h, bad[h]
    for (h in empty) printf "empty_stdout %s %d\n", h, empty[h]
    for (h in deny) printf "deny %s %d\n", h, deny[h]
    for (h in ask) printf "ask %s %d\n", h, ask[h]
    for (h in follow) printf "followup %s %d\n", h, follow[h]
  }
' "$LOG"
