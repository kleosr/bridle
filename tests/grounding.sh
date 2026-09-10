#!/usr/bin/env bash
# Sourced by run.sh. Structural shapes: hook registration, frontmatter,
# globs, SSOT references, skill routing. No prose-content assertions.

# shellcheck source=shared/hooks/lib/fleet_scan.sh
source "$PACK/shared/hooks/lib/fleet_scan.sh"

run_test "hooks.json stop loop_limit is 1" "1" "$(jq -r '.hooks.stop[0].loop_limit' "$PACK/shared/hooks/hooks.json")"
run_test "hooks.json stop failClosed is false" "false" "$(jq -r '.hooks.stop[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeSubmitPrompt failClosed is true" "true" "$(jq -r '.hooks.beforeSubmitPrompt[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeShellExecution failClosed is true" "true" "$(jq -r '.hooks.beforeShellExecution[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeReadFile failClosed is true" "true" "$(jq -r '.hooks.beforeReadFile[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeReadFile timeout is 10" "10" "$(jq -r '.hooks.beforeReadFile[0].timeout' "$PACK/shared/hooks/hooks.json")"

RESULT="$(jq -e '.hooks|has("stop")|not' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null && echo yes || echo no)"
run_test "hooks.cloud.json does not register stop (unverified on cloud)" "yes" "$RESULT"

RESULT="$(jq -e '.hooks.beforeShellExecution' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null && echo ok || echo no)"
run_test "hooks.cloud.json registers beforeShellExecution" "ok" "$RESULT"

RESULT="$(jq -r '.hooks.beforeSubmitPrompt[0].failClosed' "$PACK/shared/hooks/hooks.cloud.json")"
run_test "cloud beforeSubmitPrompt failClosed is true" "true" "$RESULT"

MDC_OK=ok
for f in "$PACK"/shared/rules/*.mdc; do
  awk 'NR==1 && $0!="---"{bad=1} /^alwaysApply:/ && $0 !~ /^alwaysApply: (true|false)$/ {bad=1} END{exit bad?1:0}' "$f" || MDC_OK="bad:$(basename "$f")"
done
run_test "every pack .mdc has valid frontmatter" "ok" "$MDC_OK"

DUP_HEAD="$(grep -h '^# ' "$PACK"/shared/rules/*.mdc | sort | uniq -d | wc -l | tr -d ' ')"
run_test "no two .mdc share a top heading" "0" "$DUP_HEAD"

GLOB_OK=ok
for f in next vite astro postgres supabase; do
  line="$(grep '^globs:' "$PACK/shared/rules/${f}.mdc" || true)"
  echo "$line" | grep -q '^globs: \[' && GLOB_OK="array:$f"
  echo "$line" | grep -q '^globs: "' && GLOB_OK="quoted:$f"
  echo "$line" | grep -q '^globs: [^["]' || GLOB_OK="missing:$f"
done
run_test "scoped rules use bare-string globs (not YAML arrays)" "ok" "$GLOB_OK"

SSOT=ok
[[ -f "$PACK/shared/config/rules.global.txt" ]] || SSOT="missing-rules.global"
grep -q 'rules.global.txt' "$PACK/shared/hooks/fleet_sync.sh" || SSOT="fleet-sync"
grep -q 'rules.global.txt' "$PACK/scripts/uninstall.sh" || SSOT="uninstall"
run_test "GLOBAL list has one SSOT (rules.global.txt)" "ok" "$SSOT"

SK_DESC=ok
while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  grep -q '^description:' "$PACK/shared/skills/$skill/SKILL.md" || SK_DESC="missing:$skill"
done < <(load_lines "$PACK/shared/config/skills.txt")
run_test "every catalog skill has a description routing contract" "ok" "$SK_DESC"

LOC_OK=1
for f in "$PACK"/shared/hooks/before_submit_prompt.sh "$PACK"/shared/hooks/before_shell.sh "$PACK"/shared/hooks/before_read_file.sh "$PACK"/shared/hooks/stop.sh; do
  n="$(wc -l < "$f")"
  [[ "$n" -le 80 ]] || { LOC_OK=0; break; }
done
run_test "event hooks LOC ≤ 80" "1" "$LOC_OK"

if ! grep -Rq --include='*.sh' 'updated_input' "$PACK/shared/hooks/" 2>/dev/null; then UP=ok; else UP=fail; fi
run_test "no updated_input in hooks" "ok" "$UP"

B_HITS="$(grep -Rn --include='*.sh' --include='*.txt' -F '\b' "$PACK/shared/hooks" 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
RESULT="$([[ -z "$B_HITS" ]] && echo ok || echo fail)"
run_test "hooks have zero GNU grep \\b (macOS BSD-safe)" "ok" "$RESULT"

RESULT="$(echo '{"command":"seq 1 400 > src/big.ts","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "pre-action gate: shell redirect into .ts denied before write" "deny" "$RESULT"

RESULT="$(echo '{"command":"bash tests/run.sh && bash scripts/doctor.sh","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "pre-action gate: repo proof command allowed" "allow" "$RESULT"
