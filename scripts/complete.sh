#!/usr/bin/env bash
# Completion-confidence scorer. Turns the deterministic signals in
# complete_gate.sh into a single confidence (0-100) and a verdict the caller
# can branch on: act when confidence is high, escalate when it is not.
#
#   bash scripts/complete.sh check [dir]   JSON on stdout; exit 0 = act,
#                                          exit 3 = escalate, exit 2 = usage.
#
# Confidence is deterministic, not a model claim. It aggregates: unresolved
# conflict markers and changed-file syntax errors (broken → escalate outright),
# source added but never wired (orphan), not-implemented stubs, and ownerless
# TODO/FIXME left in the change. The threshold is COMPLETE_MIN_CONFIDENCE
# (default 80). This scores the *shape* of the change; it never replaces the
# repo verify command (testing.mdc) — cite a real run for "done".
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=shared/hooks/lib/common.sh
source "$PACK/shared/hooks/lib/common.sh"
# shellcheck source=shared/hooks/lib/verify_gate.sh
source "$PACK/shared/hooks/lib/verify_gate.sh"
# shellcheck source=shared/hooks/lib/complete_gate.sh
source "$PACK/shared/hooks/lib/complete_gate.sh"
require_jq

CMD="${1:-}"
ROOT="${2:-$(pwd -P)}"
THRESHOLD="${COMPLETE_MIN_CONFIDENCE:-80}"

usage() {
  echo "usage: bash scripts/complete.sh check [dir]" >&2
  echo "what: deterministic completion-confidence score for the working tree vs HEAD." >&2
  echo "exit: 0 act (>= COMPLETE_MIN_CONFIDENCE, default 80), 3 escalate, 2 usage." >&2
  exit 2
}

[[ "$CMD" == "check" ]] || usage
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git work tree: $ROOT" >&2
  exit 2
fi

conflicts=0 orphans=0 dangling=0 undeclared=0 stubs=0 todos=0 syntax=0
declare -a SIGNALS=()

while IFS=$'\t' read -r kind detail; do
  [[ -n "$kind" ]] || continue
  case "$kind" in
    conflict) conflicts=$((conflicts + 1)); SIGNALS+=("conflict:$detail") ;;
    orphan)   orphans=$((orphans + 1));     SIGNALS+=("orphan:$detail") ;;
    dangling) dangling=$((dangling + 1));   SIGNALS+=("dangling:$detail") ;;
    stub)     stubs=1;                      SIGNALS+=("stub:$detail") ;;
    todo)     todos=1;                      SIGNALS+=("todo:$detail") ;;
  esac
done < <(complete_scan "$ROOT")

SYN="$(gate_verify_syntax "$ROOT" 2>/dev/null || true)"
if [[ -n "$SYN" ]]; then
  syntax=1
  while IFS= read -r line; do
    [[ -n "$line" ]] && SIGNALS+=("syntax:$line")
  done <<<"$SYN"
fi

# Dependency integrity: a package newly imported by this change that is not
# declared in package.json (any dependency field). jq-backed, so it lives here
# rather than in the hook-safe gate library. Only runs when a manifest exists;
# workspace protocol entries and Node built-ins are not flagged.
# Declared set is the union across every package.json in the tree (not just the
# root), so a monorepo's per-package dependency does not read as undeclared.
MANIFESTS="$({ git -C "$ROOT" ls-files -- '*package.json' 2>/dev/null; git -C "$ROOT" ls-files -o --exclude-standard -- '*package.json' 2>/dev/null; } | { grep -vE '(^|/)node_modules/' || true; } | sort -u)"
if [[ -n "$MANIFESTS" ]]; then
  DECLARED=""
  while IFS= read -r mf; do
    [[ -n "$mf" && -f "$ROOT/$mf" ]] || continue
    jq empty "$ROOT/$mf" >/dev/null 2>&1 || continue
    DECLARED="$DECLARED
$(jq -r '[(.dependencies//{}),(.devDependencies//{}),(.peerDependencies//{}),(.optionalDependencies//{})] | add // {} | keys[]' "$ROOT/$mf" 2>/dev/null)"
  done <<<"$MANIFESTS"
  DECLARED="$(printf '%s\n' "$DECLARED" | sort -u)"
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    printf '%s\n' "$DECLARED" | grep -qxF -- "$pkg" && continue
    undeclared=$((undeclared + 1))
    SIGNALS+=("undeclared:$pkg (imported but not declared in any package.json)")
  done < <(comp_added_imports "$ROOT")
fi

# Deterministic scoring. Broken states (conflict, syntax red) clamp low; unwired
# and stub code are heavy; ownerless TODOs are a lighter nudge.
score=100
critical=0
[[ "$conflicts" -gt 0 ]] && critical=1
[[ "$syntax" -gt 0 ]] && critical=1
orphan_pen=$((orphans * 30)); [[ "$orphan_pen" -gt 60 ]] && orphan_pen=60
score=$((score - orphan_pen))
dangling_pen=$((dangling * 40)); [[ "$dangling_pen" -gt 80 ]] && dangling_pen=80
score=$((score - dangling_pen))
undeclared_pen=$((undeclared * 40)); [[ "$undeclared_pen" -gt 80 ]] && undeclared_pen=80
score=$((score - undeclared_pen))
[[ "$stubs" -gt 0 ]] && score=$((score - 40))
[[ "$todos" -gt 0 ]] && score=$((score - 15))
[[ "$critical" -eq 1 ]] && score=0
[[ "$score" -lt 0 ]] && score=0

verdict="act"
[[ "$critical" -eq 1 || "$score" -lt "$THRESHOLD" ]] && verdict="escalate"

sig_json="$(printf '%s\n' ${SIGNALS[@]+"${SIGNALS[@]}"} | jq -R . | jq -s 'map(select(length>0))')"
jq -n \
  --argjson confidence "$score" \
  --arg verdict "$verdict" \
  --argjson threshold "$THRESHOLD" \
  --argjson critical "$([[ "$critical" -eq 1 ]] && echo true || echo false)" \
  --argjson counts "{\"conflict\":$conflicts,\"orphan\":$orphans,\"dangling\":$dangling,\"undeclared\":$undeclared,\"stub\":$stubs,\"todo\":$todos,\"syntax\":$syntax}" \
  --argjson signals "$sig_json" \
  '{confidence:$confidence,verdict:$verdict,threshold:$threshold,critical:$critical,counts:$counts,signals:$signals}'

[[ "$verdict" == "act" ]] && exit 0
exit 3
