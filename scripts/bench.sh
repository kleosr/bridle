#!/usr/bin/env bash
# Benchmark for the completion-confidence scorer. Materialises every labelled
# case in evals/bench/cases.json as a scratch git repo (base committed, change
# left as the working diff), runs scripts/complete.sh against it, and scores the
# verdict against the label. Reports the confusion matrix, accuracy / precision
# / recall / false-positive-rate, and a before/after: "before" is the pre-gate
# baseline (no completion detection: every change is treated as complete), so
# its recall on incomplete work is zero by construction.
#
#   bash scripts/bench.sh            JSON report on stdout
#   bash scripts/bench.sh --verbose  also prints a per-case table on stderr
#
# Exit 0 when accuracy >= target and false-positive-rate <= target; else 1.
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=shared/hooks/lib/common.sh
source "$PACK/shared/hooks/lib/common.sh"
require_jq

CASES="${BENCH_FILE:-$PACK/evals/bench/cases.json}"
COMPLETE="$PACK/scripts/complete.sh"
VERBOSE=0
[[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]] && VERBOSE=1

[[ -f "$CASES" ]] || { echo "missing $CASES" >&2; exit 2; }
jq empty "$CASES" >/dev/null 2>&1 || { echo "$CASES is not JSON" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/kleos-bench.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

write_files() {
  local repo="$1" arr="$2" i n path content dir
  n="$(jq -r "$arr | length" "$CASES")"
  i=0
  while [[ "$i" -lt "$n" ]]; do
    path="$(jq -r "$arr[$i].path" "$CASES")"
    content="$(jq -r "$arr[$i].content" "$CASES")"
    dir="$(dirname "$repo/$path")"
    mkdir -p "$dir"
    printf '%s' "$content" > "$repo/$path"
    i=$((i + 1))
  done
}

TP=0 FP=0 TN=0 FN=0 N=0
RESULTS="[]"

CASE_N="$(jq -r '.cases | length' "$CASES")"
c=0
while [[ "$c" -lt "$CASE_N" ]]; do
  id="$(jq -r ".cases[$c].id" "$CASES")"
  label="$(jq -r ".cases[$c].label" "$CASES")"
  repo="$WORK/$id"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email bench@local
  git -C "$repo" config user.name bench
  write_files "$repo" ".cases[$c].base"
  git -C "$repo" add -A
  git -C "$repo" commit -qm base
  write_files "$repo" ".cases[$c].change"

  out="$(bash "$COMPLETE" check "$repo" 2>/dev/null || true)"
  verdict="$(printf '%s' "$out" | jq -r '.verdict // "error"')"
  confidence="$(printf '%s' "$out" | jq -r '.confidence // -1')"

  pred_incomplete=0; [[ "$verdict" == "escalate" ]] && pred_incomplete=1
  actual_incomplete=0; [[ "$label" == "incomplete" ]] && actual_incomplete=1
  ok=0
  if [[ "$pred_incomplete" -eq 1 && "$actual_incomplete" -eq 1 ]]; then TP=$((TP+1)); ok=1
  elif [[ "$pred_incomplete" -eq 1 && "$actual_incomplete" -eq 0 ]]; then FP=$((FP+1))
  elif [[ "$pred_incomplete" -eq 0 && "$actual_incomplete" -eq 0 ]]; then TN=$((TN+1)); ok=1
  else FN=$((FN+1)); fi
  N=$((N+1))

  RESULTS="$(printf '%s' "$RESULTS" | jq \
    --arg id "$id" --arg label "$label" --arg verdict "$verdict" \
    --argjson confidence "$confidence" --argjson ok "$([[ "$ok" -eq 1 ]] && echo true || echo false)" \
    '. + [{id:$id,label:$label,verdict:$verdict,confidence:$confidence,ok:$ok}]')"
  c=$((c + 1))
done

pct() { awk -v a="$1" -v b="$2" 'BEGIN{ if (b==0) print 0; else printf "%.3f", a/b }'; }

accuracy="$(pct $((TP + TN)) "$N")"
precision="$(pct "$TP" $((TP + FP)))"
recall="$(pct "$TP" $((TP + FN)))"
fpr="$(pct "$FP" $((FP + TN)))"
pos=$((TP + FN)); neg=$((TN + FP))
before_accuracy="$(pct "$neg" "$N")"

target_acc="$(jq -r '.target.accuracy // 0.9' "$CASES")"
target_fpr="$(jq -r '.target.maxFalsePositiveRate // 0.2' "$CASES")"
pass="$(awk -v a="$accuracy" -v ta="$target_acc" -v f="$fpr" -v tf="$target_fpr" \
  'BEGIN{ print (a+1e-9>=ta && f-1e-9<=tf) ? "true" : "false" }')"

jq -n \
  --argjson n "$N" \
  --argjson matrix "{\"tp\":$TP,\"fp\":$FP,\"tn\":$TN,\"fn\":$FN}" \
  --argjson after "{\"accuracy\":$accuracy,\"precision\":$precision,\"recall\":$recall,\"falsePositiveRate\":$fpr}" \
  --argjson before "{\"accuracy\":$before_accuracy,\"recall\":0,\"note\":\"no completion detection: every change treated as complete\"}" \
  --argjson target "{\"accuracy\":$target_acc,\"maxFalsePositiveRate\":$target_fpr}" \
  --argjson pass "$pass" \
  --argjson cases "$RESULTS" \
  '{n:$n,confusionMatrix:$matrix,after:$after,before:$before,target:$target,pass:$pass,cases:$cases}'

if [[ "$VERBOSE" -eq 1 ]]; then
  printf '%s' "$RESULTS" | jq -r '.[] | "\(if .ok then "PASS" else "FAIL" end)  \(.id)  label=\(.label)  verdict=\(.verdict)  confidence=\(.confidence)"' >&2
fi

[[ "$pass" == "true" ]] && exit 0
exit 1
