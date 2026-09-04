#!/usr/bin/env bash

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"implement a login form"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit continues unbound task (no context inject)" "true" "$RESULT"
RESULT="$([[ -f "$PACK/state/route" ]] && cat "$PACK/state/route" || echo missing)"
run_test "before_submit does not write route=code" "missing" "$RESULT"

rm -rf "$PACK/state"
RESULT="$(echo '{"prompt":"the form breaks on submit"}' | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "before_submit continues bugfix prompt" "true" "$RESULT"
RESULT="$(cat "$PACK/state/route" 2>/dev/null || echo missing)"
run_test "before_submit does not route bugfix" "missing" "$RESULT"

if ! grep -Rq --include='*.sh' 'updated_input' "$PACK/shared/hooks/" 2>/dev/null && [[ ! -e "$PACK/shared/hooks/kleos-gate" ]]; then
  echo "[pass] no updated_input / Rust gate"; PASS=$((PASS + 1))
else
  echo "[fail] updated_input or Rust gate found"; FAIL=$((FAIL + 1))
fi

if grep -q '"timeout"' "$PACK/shared/hooks/hooks.json" && ! grep -q 'timeoutSec' "$PACK/shared/hooks/hooks.json"; then
  echo "[pass] hooks.json uses timeout (not timeoutSec)"; PASS=$((PASS + 1))
else
  echo "[fail] hooks.json timeout field wrong"; FAIL=$((FAIL + 1))
fi

run_test "ponytail.mdc states hard 300" "1" "$(grep -c 'hard 300' "$PACK/shared/rules/ponytail.mdc" | tr -d ' ')"
run_test "ponytail.mdc states split before 120" "1" "$(grep -c 'split before 120' "$PACK/shared/rules/ponytail.mdc" | tr -d ' ')"
run_test "ponytail.mdc states >700 rewrite" "1" "$(grep -c '>700' "$PACK/shared/rules/ponytail.mdc" | tr -d ' ')"
run_test "ponytail.mdc states never 500" "1" "$(grep -c 'never 500' "$PACK/shared/rules/ponytail.mdc" | tr -d ' ')"
run_test "complexity.mdc states never above 22" "1" "$(grep -c 'Never above \*\*22\*\*' "$PACK/shared/rules/complexity.mdc" | tr -d ' ')"
run_test "types.mdc is alwaysApply" "true" "$(awk '/^alwaysApply:/{print $2; exit}' "$PACK/shared/rules/types.mdc")"
run_test "testing.mdc is alwaysApply" "true" "$(awk '/^alwaysApply:/{print $2; exit}' "$PACK/shared/rules/testing.mdc")"
run_test "paste charter still has Cursor + Grok lock" "1" "$(grep -c '## Cursor + Grok' "$PACK/shared/rules/USER-RULES.paste.txt" | tr -d ' ')"
run_test "paste states never above 22" "1" "$(grep -c 'never above 22' "$PACK/shared/rules/USER-RULES.paste.txt" | tr -d ' ')"

LOC_OK=1
for f in "$PACK"/shared/hooks/session_start.sh "$PACK"/shared/hooks/before_submit_prompt.sh "$PACK"/shared/hooks/before_shell.sh "$PACK"/shared/hooks/before_read_file.sh "$PACK"/shared/hooks/stop.sh; do
  n="$(wc -l < "$f")"
  [[ "$n" -le 80 ]] || { LOC_OK=0; break; }
done
run_test "event hooks LOC ≤ 80" "1" "$LOC_OK"

RESULT="$(HERE="$PACK/shared/hooks" bash -c 'source "$0/lib/common.sh" && type emit_ask >/dev/null && type emit_allow >/dev/null && echo ok' "$PACK/shared/hooks" 2>/dev/null || echo fail)"
run_test "lib/common.sh emit_ask available" "ok" "$RESULT"

B_HITS="$(grep -Rn --include='*.sh' --include='*.txt' -F '\b' "$PACK/shared/hooks" 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
RESULT="$([[ -z "$B_HITS" ]] && echo ok || echo fail)"
run_test "hooks have zero GNU grep \\\\b (macOS BSD-safe)" "ok" "$RESULT"
