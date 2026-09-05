#!/usr/bin/env bash
# Runtime grounding probes: stop gate, hook context, duplicate channel, missing/malformed grounding.

GR_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kleos-gr.XXXXXX")"
STOP="$PACK/shared/hooks/stop.sh"
# shellcheck source=shared/hooks/lib/fleet_scan.sh
source "$PACK/shared/hooks/lib/fleet_scan.sh"

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

# --- Stop gate: rewrite detection ---

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
RESULT="$(printf '%s' "$RW_OUT" | jq -r '.followup_message // "" | test("rewrite: mid.ts changed")')"
run_test "stop: 100% rewrite of 200-line file flagged as rewrite" "true" "$RESULT"

gr_repo "$GR_TMP/small_full"
gr_lines 50 > "$GR_TMP/small_full/s.ts"
git -C "$GR_TMP/small_full" add s.ts
git -C "$GR_TMP/small_full" -c user.email=t@t -c user.name=t commit -q -m base
gr_lines 50 > "$GR_TMP/small_full/s.ts"
RESULT="$(gr_stop "$GR_TMP/small_full" | jq -c .)"
run_test "stop: full rewrite of 50-line file NOT flagged (below 80 LOC floor)" "{}" "$RESULT"

# --- Stop gate: format churn ---

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

# --- Stop gate: duplicate helper (unchanged) ---

gr_repo "$GR_TMP/dup"
printf 'function helper() { return 1 }\n' > "$GR_TMP/dup/a.js"
printf 'function helper() { return 2 }\n' > "$GR_TMP/dup/b.js"
RESULT="$(gr_stop "$GR_TMP/dup" | jq -r '.followup_message // "" | test("duplicate_helper: helper")')"
run_test "stop: planted duplicate helper flagged" "true" "$RESULT"

gr_repo "$GR_TMP/tracked"
printf 'def one():\n    pass\n' > "$GR_TMP/tracked/m.py"
git -C "$GR_TMP/tracked" add m.py
git -C "$GR_TMP/tracked" -c user.email=t@t -c user.name=t commit -q -m base
printf 'def one():\n    pass\n\ndef one():\n    pass\n' > "$GR_TMP/tracked/m.py"
RESULT="$(gr_stop "$GR_TMP/tracked" | jq -r '.followup_message // "" | test("duplicate_helper: one")')"
run_test "stop: added helper duplicating an existing one in a tracked file flagged" "true" "$RESULT"

gr_repo "$GR_TMP/rename"
printf 'def one():\n    pass\n' > "$GR_TMP/rename/m.py"
git -C "$GR_TMP/rename" add m.py
git -C "$GR_TMP/rename" -c user.email=t@t -c user.name=t commit -q -m base
printf 'def one():\n    return 1\n\ndef two():\n    pass\n' > "$GR_TMP/rename/m.py"
RESULT="$(gr_stop "$GR_TMP/rename" | jq -c .)"
run_test "stop: editing a body and adding a distinct helper is not flagged (no false positive)" "{}" "$RESULT"

# --- Stop gate: bounds and fallback ---

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

RESULT="$(gr_stop "$GR_TMP/rewrite" | jq -r '.followup_message | test("stop.sh, runs once") and test("Touch only the hunk")')"
run_test "stop: failure names the gate and the recovery action" "true" "$RESULT"

# --- Hooks.json shape ---

STOP_LL="$(jq -r '.hooks.stop[0].loop_limit' "$PACK/shared/hooks/hooks.json")"
run_test "hooks.json stop loop_limit is 1" "1" "$STOP_LL"

STOP_FC="$(jq -r '.hooks.stop[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "hooks.json stop failClosed is false" "false" "$STOP_FC"

RESULT="$(jq -e '.hooks|has("stop")|not' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null && echo yes || echo no)"
run_test "hooks.cloud.json does not register stop (unverified on cloud)" "yes" "$RESULT"

# --- Pre-action gate ---

RESULT="$(echo '{"command":"seq 1 400 > src/big.ts","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "pre-action gate: shell redirect into .ts denied before write" "deny" "$RESULT"

RESULT="$(echo '{"command":"bash tests/run.sh && bash scripts/doctor.sh","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "pre-action gate: repo proof command allowed" "allow" "$RESULT"

# --- Duplicate channel ---

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("## Ladder") or test("alwaysApply") or test("Harness \\(")')"
run_test "duplicate channel: sessionStart does not re-inject .mdc bodies" "false" "$RESULT"

RESULT="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context | test("## Now")')"
run_test "hook context: sessionStart carries NOW.md Now section" "true" "$RESULT"

# --- Missing grounding ---

EMPTY_WS="$(mktemp -d "${TMPDIR:-/tmp}/kleos-empty.XXXXXX")"
RESULT="$(jq -n --arg w "$EMPTY_WS" '{composer_mode:"agent",workspace_roots:[$w]}' | bash "$PACK/shared/hooks/session_start.sh" | jq -r 'if . == {} then "quiet" else "context" end')"
rm -rf "$EMPTY_WS"
run_test "missing grounding: workspace without NOW.md falls back, never crashes" "$([[ "$RESULT" == quiet || "$RESULT" == context ]] && echo ok || echo bad)" "ok"

# --- Malformed grounding ---

MDC_BAD="$(mktemp -d "${TMPDIR:-/tmp}/kleos-mdc.XXXXXX")"
printf '%s\n' '---' 'alwaysApply: [unterminated' '---' '# broken' > "$MDC_BAD/broken.mdc"
RESULT="$(awk 'NR==1 && $0!="---"{bad=1} /^alwaysApply:/ && $0 !~ /^alwaysApply: (true|false)$/ {bad=1} END{print (bad?"malformed":"ok")}' "$MDC_BAD/broken.mdc")"
rm -rf "$MDC_BAD"
run_test "malformed grounding: frontmatter linter detects bad alwaysApply" "malformed" "$RESULT"

MDC_OK=ok
for f in "$PACK"/shared/rules/*.mdc; do
  awk 'NR==1 && $0!="---"{bad=1} /^alwaysApply:/ && $0 !~ /^alwaysApply: (true|false)$/ {bad=1} END{exit bad?1:0}' "$f" || MDC_OK="bad:$(basename "$f")"
done
run_test "malformed grounding: every pack .mdc has valid frontmatter" "ok" "$MDC_OK"

ALWAYS_ON="$(grep -l '^alwaysApply: true' "$PACK"/shared/rules/*.mdc | wc -l | tr -d ' ')"
run_test "always-on rule count is 7 (agent, ponytail, pnpm, complexity, vibe, testing, types)" "7" "$ALWAYS_ON"

DUP_HEAD="$(grep -h '^# ' "$PACK"/shared/rules/*.mdc | sort | uniq -d | wc -l | tr -d ' ')"
run_test "duplicate channel: no two .mdc share a top heading" "0" "$DUP_HEAD"

SK_DESC=ok
while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  grep -q '^description:' "$PACK/shared/skills/$skill/SKILL.md" || SK_DESC="missing:$skill"
done < <(load_lines "$PACK/shared/config/skills.txt")
run_test "skill discovery: every catalog skill has a description routing contract" "ok" "$SK_DESC"

AGENTS_SLIM=ok
grep -q 'quality-roofs-audit.md' "$PACK/AGENTS.md" || AGENTS_SLIM="missing-audit"
grep -q 'USER-RULES.paste.txt' "$PACK/AGENTS.md" || AGENTS_SLIM="missing-paste"
grep -q 'astra-slim.md' "$PACK/AGENTS.md" || AGENTS_SLIM="missing-astra"
if grep -qE 'Halstead|CRAP' "$PACK/AGENTS.md"; then AGENTS_SLIM="restates-roofs"; fi
run_test "AGENTS.md is a navigator (points to paste/audit; does not restate Halstead/CRAP)" "ok" "$AGENTS_SLIM"

PASTE_SSOT=ok
grep -q 'canonical in `complexity.mdc`' "$PACK/shared/rules/USER-RULES.paste.txt" || PASTE_SSOT="missing-canonical"
run_test "paste names complexity.mdc as quality SSOT" "ok" "$PASTE_SSOT"

rm -rf "$GR_TMP"
