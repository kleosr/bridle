#!/usr/bin/env bash
# Sourced by run.sh. Stop-gate behavior on scratch git repos.

GR_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kleos-gr.XXXXXX")"
STOP="$PACK/shared/hooks/stop.sh"

gr_repo() {
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

gr_lines() {
  local n="$1" i=1
  while [[ "$i" -le "$n" ]]; do printf 'export const v%s = %s\n' "$i" "$i"; i=$((i + 1)); done
}

gr_stop() {
  jq -n --arg w "$1" --arg s "${2:-completed}" --argjson l "${3:-0}" '{status:$s,loop_count:$l,workspace_roots:[$w]}' | bash "$STOP"
}

gr_repo "$GR_TMP/hunk_in_big"
gr_lines 350 > "$GR_TMP/hunk_in_big/big.ts"
git -C "$GR_TMP/hunk_in_big" add big.ts
git -C "$GR_TMP/hunk_in_big" -c user.email=t@t -c user.name=t commit -q -m base
awk 'NR==3 { print "export const v3 = 999"; next } { print }' "$GR_TMP/hunk_in_big/big.ts" > "$GR_TMP/hunk_in_big/big.ts.tmp"
mv "$GR_TMP/hunk_in_big/big.ts.tmp" "$GR_TMP/hunk_in_big/big.ts"
RESULT="$(gr_stop "$GR_TMP/hunk_in_big" | jq -c .)"
run_test "stop: 3-line fix in 350-line file is NOT flagged (no drive-by)" "{}" "$RESULT"

gr_repo "$GR_TMP/rewrite"
gr_lines 200 > "$GR_TMP/rewrite/mid.ts"
git -C "$GR_TMP/rewrite" add mid.ts
git -C "$GR_TMP/rewrite" -c user.email=t@t -c user.name=t commit -q -m base
seq 1 200 | sed 's/^/export const w/' > "$GR_TMP/rewrite/mid.ts"
RW_OUT="$(gr_stop "$GR_TMP/rewrite")"
RESULT="$(printf '%s' "$RW_OUT" | jq -r '.followup_message // "" | test("churn: mid.ts diff")')"
run_test "stop: 100% rewrite of 200-line file flagged as churn" "true" "$RESULT"

gr_repo "$GR_TMP/small_full"
gr_lines 50 > "$GR_TMP/small_full/s.ts"
git -C "$GR_TMP/small_full" add s.ts
git -C "$GR_TMP/small_full" -c user.email=t@t -c user.name=t commit -q -m base
gr_lines 50 > "$GR_TMP/small_full/s.ts"
RESULT="$(gr_stop "$GR_TMP/small_full" | jq -c .)"
run_test "stop: full rewrite of 50-line file NOT flagged (below 80 LOC floor)" "{}" "$RESULT"

gr_repo "$GR_TMP/reindent"
{ i=1; while [[ "$i" -le 15 ]]; do printf 'function f%s() {\n  return %s\n}\n' "$i" "$i"; i=$((i + 1)); done; } > "$GR_TMP/reindent/indent.js"
git -C "$GR_TMP/reindent" add indent.js
git -C "$GR_TMP/reindent" -c user.email=t@t -c user.name=t commit -q -m base
{ i=1; while [[ "$i" -le 15 ]]; do printf 'function f%s() {\n    return %s\n}\n' "$i" "$i"; i=$((i + 1)); done; } > "$GR_TMP/reindent/indent.js"
RESULT="$(gr_stop "$GR_TMP/reindent" | jq -r '.followup_message // "" | test("format_churn: indent.js")')"
run_test "stop: pure reindent (2-space to 4-space) flagged as format_churn" "true" "$RESULT"

gr_repo "$GR_TMP/real_fix_ws"
printf 'function a() {\n  return 1\n}\n' > "$GR_TMP/real_fix_ws/fix.js"
git -C "$GR_TMP/real_fix_ws" add fix.js
git -C "$GR_TMP/real_fix_ws" -c user.email=t@t -c user.name=t commit -q -m base
printf 'function a() {\n  return 999\n}\n' > "$GR_TMP/real_fix_ws/fix.js"
RESULT="$(gr_stop "$GR_TMP/real_fix_ws" | jq -c .)"
run_test "stop: real 1-line fix with minor ws is NOT flagged" "{}" "$RESULT"

RESULT="$(gr_stop "$GR_TMP/hunk_in_big" completed 1 | jq -c .)"
run_test "stop: loop_count 1 is quiet (bounded, no loop)" "{}" "$RESULT"

RESULT="$(gr_stop "$GR_TMP/hunk_in_big" aborted 0 | jq -c .)"
run_test "stop: aborted status is quiet" "{}" "$RESULT"

RESULT="$(printf 'not json' | bash "$STOP" | jq -c .)"
run_test "stop: malformed stdin emits {} (fail-open, exit 0)" "{}" "$RESULT"

RESULT="$(echo '{}' | bash "$STOP" | jq -c .)"
run_test "stop: missing workspace_roots emits {}" "{}" "$RESULT"

mkdir -p "$GR_TMP/nogit"
RESULT="$(gr_stop "$GR_TMP/nogit" | jq -c .)"
run_test "stop: non-git workspace emits {} (explicit fallback)" "{}" "$RESULT"

RESULT="$(gr_stop "$GR_TMP/rewrite" | jq -r '.followup_message | test("advisory") and test("Narrow your hunks")')"
run_test "stop: failure names the gate and the recovery action" "true" "$RESULT"

RESULT="$(gr_stop "$GR_TMP/rewrite" | jq -r 'has("followup_message") and (has("permission")|not) and (has("continue")|not)')"
run_test "stop: churn warning is advisory followup, not refusal" "true" "$RESULT"

gr_repo "$GR_TMP/badshell"
printf 'echo ok\n' > "$GR_TMP/badshell/ok.sh"
git -C "$GR_TMP/badshell" add ok.sh
git -C "$GR_TMP/badshell" -c user.email=t@t -c user.name=t commit -q -m base
printf 'echo ok\nif then\n' > "$GR_TMP/badshell/ok.sh"
RESULT="$(gr_stop "$GR_TMP/badshell" | jq -r '.followup_message // "" | test("VERIFY")')"
run_test "stop: bash -n failure on changed .sh is advisory VERIFY" "true" "$RESULT"

gr_repo "$GR_TMP/okshell"
printf 'echo ok\n' > "$GR_TMP/okshell/ok.sh"
git -C "$GR_TMP/okshell" add ok.sh
git -C "$GR_TMP/okshell" -c user.email=t@t -c user.name=t commit -q -m base
printf 'echo still-ok\n' > "$GR_TMP/okshell/ok.sh"
RESULT="$(gr_stop "$GR_TMP/okshell" | jq -c .)"
run_test "stop: valid .sh edit without churn is quiet (hook does not run tests)" "{}" "$RESULT"

rm -rf "$GR_TMP"
