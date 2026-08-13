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

COMMENT_MAX="$(jq -r '.comment_ratio_max' "$PACK/shared/hooks/policy/lean.json")"
run_test "lean.json comment_ratio_max is 2 (zero-comment)" "2" "$COMMENT_MAX"
run_test "lean.json file_loc_soft is 120" "120" "$(jq -r '.file_loc_soft' "$PACK/shared/hooks/policy/lean.json")"
run_test "lean.json file_loc_max is 300" "300" "$(jq -r '.file_loc_max' "$PACK/shared/hooks/policy/lean.json")"
run_test "lean.json file_loc_legacy_emergency is 700" "700" "$(jq -r '.file_loc_legacy_emergency' "$PACK/shared/hooks/policy/lean.json")"

LOC_OK=1
for f in "$PACK"/shared/hooks/session_start.sh "$PACK"/shared/hooks/before_submit_prompt.sh "$PACK"/shared/hooks/before_shell.sh "$PACK"/shared/hooks/before_read_file.sh; do
  n="$(wc -l < "$f")"
  [[ "$n" -le 80 ]] || { LOC_OK=0; break; }
done
run_test "event hooks LOC ≤ 80" "1" "$LOC_OK"

RESULT="$(HERE="$PACK/shared/hooks" bash -c 'source "$0/lib/common.sh" && type emit_ask >/dev/null && type emit_allow >/dev/null && echo ok' "$PACK/shared/hooks" 2>/dev/null || echo fail)"
run_test "lib/common.sh emit_ask available" "ok" "$RESULT"

B_HITS="$(grep -Rn --include='*.sh' --include='*.txt' -F '\b' "$PACK/shared/hooks" 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
RESULT="$([[ -z "$B_HITS" ]] && echo ok || echo fail)"
run_test "hooks have zero GNU grep \\\\b (macOS BSD-safe)" "ok" "$RESULT"
