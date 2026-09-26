#!/usr/bin/env bash
# Sourced by run.sh. Structural shapes: hook registration, frontmatter,
# globs, SSOT references, skill routing. No prose-content assertions.

# shellcheck source=shared/hooks/lib/fleet_scan.sh
source "$PACK/shared/hooks/lib/fleet_scan.sh"

run_test "hooks.json does not register stop" "false" "$(jq -r '.hooks | has("stop")' "$PACK/shared/hooks/hooks.json")"
run_test "beforeSubmitPrompt failClosed is true" "true" "$(jq -r '.hooks.beforeSubmitPrompt[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeShellExecution failClosed is true" "true" "$(jq -r '.hooks.beforeShellExecution[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeReadFile failClosed is true" "true" "$(jq -r '.hooks.beforeReadFile[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeReadFile timeout is 30 (regression: 10s timed out under MSYS spawn latency)" "30" "$(jq -r '.hooks.beforeReadFile[0].timeout' "$PACK/shared/hooks/hooks.json")"
run_test "beforeShellExecution timeout is 60" "60" "$(jq -r '.hooks.beforeShellExecution[0].timeout' "$PACK/shared/hooks/hooks.json")"

RESULT="$(jq -e '.hooks|has("stop")|not' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null && echo yes || echo no)"
run_test "hooks.cloud.json does not register stop" "yes" "$RESULT"

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

SIDE=ok
for pair in \
  code-architecture/references/placement.md \
  code-architecture/scripts/quality-gate.mjs \
  cqrs-data-flow/references/sql-repository.md \
  live-ui-sync/references/sidebar-modules.md \
  system-design/references/capacity-and-scaling.md \
  system-design/references/realtime-and-rate-limits.md \
  auth-boundaries/references/tokens-and-sessions.md
do
  [[ -f "$PACK/shared/skills/$pair" ]] || SIDE="missing:$pair"
done
run_test "engineering skills keep their references and the quality gate" "ok" "$SIDE"
RESULT="$(test -d "$PACK/shared/skills/bridle-harness/references" && echo present || echo absent)"
run_test "bridle-harness does not vendor a second copy of the law" "absent" "$RESULT"

KLEOSR_MODE="$PACK/shared/skills/kleosr/SKILL.md"
run_test "kleosr custom mode name matches its skill folder" "kleosr" "$(awk -F ': ' '$1 == "name" { print $2; exit }' "$KLEOSR_MODE")"
run_test "kleosr skill is marked as a custom mode" "true" "$(awk -F ': ' '$1 == "mode" { print $2; exit }' "$KLEOSR_MODE")"
run_test "kleosr mode requires explicit invocation" "true" "$(awk -F ': ' '$1 == "disable-model-invocation" { print $2; exit }' "$KLEOSR_MODE")"
# prompt-brief stops before editing; auto-loading it would add a round trip to every ask.
run_test "prompt-brief requires explicit invocation" "true" "$(awk -F ': ' '$1 == "disable-model-invocation" { print $2; exit }' "$PACK/shared/skills/prompt-brief/SKILL.md")"

# The instruction order is written once, in the charter's Session list.
CHARTER_AUTH="$(awk '
  /^## Session$/ { p=1; next }
  p && /^## / { exit }
  p && /^[0-9]+\. / { print }
' "$PACK/shared/rules/charter.txt")"
RESULT="$(printf '%s\n' "$CHARTER_AUTH" | grep -q 'AGENTS.md' && echo fail || echo ok)"
run_test "regression: charter order does not rank AGENTS.md as a law layer" "ok" "$RESULT"
RESULT="$(printf '%s\n' "$CHARTER_AUTH" | grep -q 'SECURITY.md' && echo ok || echo fail)"
run_test "charter order numbers SECURITY.md as a boundary layer" "ok" "$RESULT"
RESULT="$(printf '%s\n' "$CHARTER_AUTH" | grep -q 'core.mdc' && printf '%s\n' "$CHARTER_AUTH" | grep -q 'testing.mdc' && echo ok || echo fail)"
run_test "charter order numbers always-on core.mdc and testing.mdc" "ok" "$RESULT"
CHARTER_N="$(printf '%s\n' "$CHARTER_AUTH" | grep -n 'This charter' | head -1 | cut -d: -f1 || true)"
SEC_N="$(printf '%s\n' "$CHARTER_AUTH" | grep -n 'SECURITY.md' | head -1 | cut -d: -f1 || true)"
CORE_N="$(printf '%s\n' "$CHARTER_AUTH" | grep -n 'core.mdc' | head -1 | cut -d: -f1 || true)"
if [[ -n "$CHARTER_N" && -n "$SEC_N" && -n "$CORE_N" && "$CHARTER_N" -lt "$SEC_N" && "$SEC_N" -lt "$CORE_N" ]]; then
  AUTH_ORDER=ok
else
  AUTH_ORDER="charter:${CHARTER_N:-missing} security:${SEC_N:-missing} core:${CORE_N:-missing}"
fi
run_test "charter order is charter, SECURITY, then always-on" "ok" "$AUTH_ORDER"
RESULT="$(grep -qE '^[0-9]+\. ' "$KLEOSR_MODE" && grep -q 'SECURITY.md' "$KLEOSR_MODE" && echo restated || echo ok)"
run_test "regression: kleosr mode does not restate the instruction order" "ok" "$RESULT"
ROUTER="$PACK/shared/skills/bridle-harness/SKILL.md"
RESULT="$(grep -q 'SECURITY.md' "$ROUTER" && echo restated || echo ok)"
run_test "regression: bridle-harness does not restate the instruction order" "ok" "$RESULT"
RESULT="$(grep -qiw 'stop' "$ROUTER" && echo stale || echo ok)"
run_test "regression: bridle-harness does not name a stop hook" "ok" "$RESULT"
ROUTE_OK=ok
while IFS= read -r skill; do
  case "$skill" in ''|kleosr|bridle-harness) continue ;; esac
  grep -q "\`$skill\`" "$ROUTER" || ROUTE_OK="unrouted:$skill"
done < <(load_lines "$PACK/shared/config/skills.txt")
run_test "bridle-harness routes every catalog skill" "ok" "$ROUTE_OK"
# An always-trigger description loads the skill on unrelated asks and widens the diff.
ALWAYS_OK=ok
while IFS= read -r skill; do
  case "$skill" in ''|bridle-harness) continue ;; esac
  awk '/^---$/{c++; next} c==1' "$PACK/shared/skills/$skill/SKILL.md" | grep -q 'SIEMPRE' && ALWAYS_OK="always:$skill"
done < <(load_lines "$PACK/shared/config/skills.txt")
run_test "regression: engineering skills do not trigger SIEMPRE" "ok" "$ALWAYS_OK"

LOC_OK=1
for f in "$PACK"/shared/hooks/before_submit_prompt.sh "$PACK"/shared/hooks/before_shell.sh "$PACK"/shared/hooks/before_read_file.sh; do
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

[[ -e "$PACK/shared/hooks/lib/host.sh" ]] && HOSTLIB=present || HOSTLIB=absent
run_test "regression: pack does not ship lib/host.sh" "absent" "$HOSTLIB"
[[ -e "$PACK/shared/hosts" ]] && HOSTDIR=present || HOSTDIR=absent
run_test "regression: pack does not ship shared/hosts" "absent" "$HOSTDIR"

CHARTER="$PACK/shared/rules/charter.txt"
if grep -qE 'Never above|useEffect|failClosed|globs:' "$CHARTER"; then CHARTER_DUP=fail; else CHARTER_DUP=ok; fi
run_test "regression: charter does not restate core.mdc or hook internals" "ok" "$CHARTER_DUP"

CHARTER_COPIES="$(grep -Rnl 'You are kleosr'"'"'s engineering partner' "$PACK/shared" "$PACK/AGENTS.md" "$PACK/docs" 2>/dev/null | wc -l | tr -d ' ')"
run_test "regression: charter body has one copy in the pack" "1" "$CHARTER_COPIES"
if grep -q 'Observability is command' "$CHARTER"; then CHARTER_DRIFT=fail; else CHARTER_DRIFT=ok; fi
run_test "regression: paste stays the thin charter (no settings-copy essay)" "ok" "$CHARTER_DRIFT"

if grep -q '## First reads' "$PACK/AGENTS.md"; then READS=fail; else READS=ok; fi
run_test "regression: AGENTS.md does not mandate a first-read stack" "ok" "$READS"
FEAT_LINE="$(grep 'features.json' "$PACK/AGENTS.md" || true)"
if printf '%s' "$FEAT_LINE" | grep -q 'in_progress'; then FEAT_COND=ok; else FEAT_COND=fail; fi
run_test "regression: features.json is read only when a feature is in_progress or the ledger changes" "ok" "$FEAT_COND"

