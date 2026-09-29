#!/usr/bin/env bash
# Sourced by run.sh: the scope-eval scorer, judged on golden overlays. No agent runs here.

SE="$PACK/scripts/scope_eval.sh"
SE_TASKS="$PACK/evals/scope"

# se_dir ID [OVERLAY]: a committed fixture repo, optionally with an overlay applied on top.
se_dir() {
  local d; d="$(mktemp -d "${TMPDIR:-/tmp}/kleos-se.XXXXXX")"
  cp -a "$SE_TASKS/$1/repo/." "$d/"
  git -C "$d" init -q; git -C "$d" add -A
  git -C "$d" -c user.name=eval -c user.email=eval@local commit -qm base
  [[ -z "${2:-}" ]] || cp -a "$SE_TASKS/$1/$2/." "$d/"
  printf '%s' "$d"
}
# se_report ID OVERLAY: the scorer's report for the fixture with that overlay.
se_report() { local d; d="$(se_dir "$1" "$2")"; bash "$SE" score "$1" "$d" 2>&1 || true; rm -rf "$d"; }

for SE_ID in $(ls "$SE_TASKS"); do
  RESULT="$(bash "$SE" check "$SE_ID" >/dev/null 2>&1 && echo ok || echo fail)"
  run_test "scope eval $SE_ID: golden change scores and golden over-edit is rejected" "ok" "$RESULT"
done

REPORT="$(se_report fix-one-line bad)"
RESULT="$(printf '%s\n' "$REPORT" | grep -q '^FAIL prod lines' && printf '%s\n' "$REPORT" | grep -q '^ok   verify' && echo ok || echo fail)"
run_test "regression: a green but sprawling fix is rejected on production lines" "ok" "$RESULT"
REPORT="$(se_report fix-in-place bad)"
RESULT="$(printf '%s\n' "$REPORT" | grep -q '^FAIL prod lines' && printf '%s\n' "$REPORT" | grep -q '^ok   verify' && printf '%s\n' "$REPORT" | grep -q '^FAIL absent src/paginate.js: throw' && echo ok || echo fail)"
run_test "regression: a fix that adds unrequested validation and restyles neighbours is rejected" "ok" "$RESULT"
REPORT="$(se_report fix-in-long-function bad)"
RESULT="$(printf '%s\n' "$REPORT" | grep -q '^FAIL prod lines' && printf '%s\n' "$REPORT" | grep -q '^ok   verify' && printf '%s\n' "$REPORT" | grep -q '^FAIL contains src/invoice.js: for ' && echo ok || echo fail)"
run_test "regression: a one-operator fix buried in a long function is rejected when the function is rewritten" "ok" "$RESULT"
REPORT="$(se_report wire-new-route bad)"
RESULT="$(printf '%s\n' "$REPORT" | grep -q '^FAIL verify' && printf '%s\n' "$REPORT" | grep -q '^FAIL contains src/router.js' && echo ok || echo fail)"
run_test "regression: a handler that is never registered is rejected as unfinished" "ok" "$RESULT"
REPORT="$(se_report multi-part-ask bad)"
RESULT="$(printf '%s\n' "$REPORT" | grep -q '^FAIL contains README.md' && ! printf '%s\n' "$REPORT" | grep -q '^FAIL contains src/cli.js' && echo ok || echo fail)"
run_test "regression: a dropped part of a multi-part ask is rejected" "ok" "$RESULT"

SE_D="$(se_dir fix-one-line)"
seq 60 >>"$SE_D/test/price.test.js"; seq 60 >"$SE_D/README.md"
run_test "scope churn ignores tests and docs" "0 0" "$(bash "$SE" churn "$SE_D")"
printf 'a\nb\nc\n' >"$SE_D/src/extra.js"
run_test "scope churn counts an untracked production file" "3 1" "$(bash "$SE" churn "$SE_D")"
rm -rf "$SE_D"
