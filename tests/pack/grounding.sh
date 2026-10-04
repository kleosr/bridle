#!/usr/bin/env bash
# Sourced by run.sh. Structural shapes: hook registration, frontmatter,
# globs, SSOT references, skill routing. No prose-content assertions.

# shellcheck source=hosts/lib.sh
source "$PACK/hosts/lib.sh"

STOP_CMD="$(jq -r '.hooks.stop[0].command // ""' "$PACK/hosts/cursor/hooks.json")"
STOP_LIM="$(jq -r '.hooks.stop[0].loop_limit // ""' "$PACK/hosts/cursor/hooks.json")"
run_test "hooks.json stop command runs verdict turn-check" "yes" "$([[ "$STOP_CMD" == *turn-check* ]] && echo yes || echo no)"
run_test "hooks.json stop loop_limit is 1" "1" "$STOP_LIM"
run_test "beforeSubmitPrompt failClosed is true" "true" "$(jq -r '.hooks.beforeSubmitPrompt[0].failClosed' "$PACK/hosts/cursor/hooks.json")"
run_test "beforeShellExecution failClosed is true" "true" "$(jq -r '.hooks.beforeShellExecution[0].failClosed' "$PACK/hosts/cursor/hooks.json")"
run_test "beforeReadFile failClosed is true" "true" "$(jq -r '.hooks.beforeReadFile[0].failClosed' "$PACK/hosts/cursor/hooks.json")"
run_test "beforeReadFile timeout is 30 (regression: 10s timed out under MSYS spawn latency)" "30" "$(jq -r '.hooks.beforeReadFile[0].timeout' "$PACK/hosts/cursor/hooks.json")"
run_test "beforeShellExecution timeout is 60" "60" "$(jq -r '.hooks.beforeShellExecution[0].timeout' "$PACK/hosts/cursor/hooks.json")"

RESULT="$(jq -e '.hooks|has("stop")|not' "$PACK/hosts/cursor/hooks.cloud.json" >/dev/null && echo yes || echo no)"
run_test "hooks.cloud.json does not register stop" "yes" "$RESULT"

RESULT="$(jq -e '.hooks.beforeShellExecution' "$PACK/hosts/cursor/hooks.cloud.json" >/dev/null && echo ok || echo no)"
run_test "hooks.cloud.json registers beforeShellExecution" "ok" "$RESULT"

RESULT="$(jq -r '.hooks.beforeSubmitPrompt[0].failClosed' "$PACK/hosts/cursor/hooks.cloud.json")"
run_test "cloud beforeSubmitPrompt failClosed is true" "true" "$RESULT"

MDC_OK=ok
for f in "$PACK"/rules/*.mdc; do
  awk 'NR==1 && $0!="---"{bad=1} /^alwaysApply:/ && $0 !~ /^alwaysApply: (true|false)$/ {bad=1} END{exit bad?1:0}' "$f" || MDC_OK="bad:$(basename "$f")"
done
run_test "every pack .mdc has valid frontmatter" "ok" "$MDC_OK"

DUP_HEAD="$(grep -h '^# ' "$PACK"/rules/*.mdc | sort | uniq -d | wc -l | tr -d ' ')"
run_test "no two .mdc share a top heading" "0" "$DUP_HEAD"

GLOB_OK=ok
for f in next vite astro postgres supabase; do
  line="$(grep '^globs:' "$PACK/rules/${f}.mdc" || true)"
  echo "$line" | grep -q '^globs: \[' && GLOB_OK="array:$f"
  echo "$line" | grep -q '^globs: "' && GLOB_OK="quoted:$f"
  echo "$line" | grep -q '^globs: [^["]' || GLOB_OK="missing:$f"
done
run_test "scoped rules use bare-string globs (not YAML arrays)" "ok" "$GLOB_OK"

RULES_OK=ok
while IFS= read -r r; do
  [[ -f "$PACK/rules/$r.mdc" ]] || RULES_OK="missing:$r"
done < <(manifest_list '.rules[]')
run_test "every manifest rule has rules/<name>.mdc" "ok" "$RULES_OK"

SK_DESC=ok
while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  grep -q '^description:' "$PACK/skills/$skill/SKILL.md" || SK_DESC="missing:$skill"
done < <(manifest_list '.skills[]')
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
  [[ -f "$PACK/skills/$pair" ]] || SIDE="missing:$pair"
done
run_test "engineering skills keep their references and the quality gate" "ok" "$SIDE"
RESULT="$(test -d "$PACK/skills/bridle-harness/references" && echo present || echo absent)"
run_test "bridle-harness does not vendor a second copy of the law" "absent" "$RESULT"

RESULT="$(test -e "$PACK/skills/kleosr" && echo present || echo absent)|$(manifest_list '.retiredSkills[]' | grep -cx kleosr || true)"
run_test "regression: one router, the kleosr mode is retired into bridle-harness" "absent|1" "$RESULT"
run_test "bridle-harness is the Cursor custom mode" "true" "$(awk -F ': ' '$1 == "mode" { print $2; exit }' "$PACK/skills/bridle-harness/SKILL.md")"
run_test "regression: bridle-harness router loads only when invoked" "true" "$(awk -F ': ' '$1 == "disable-model-invocation" { print $2; exit }' "$PACK/skills/bridle-harness/SKILL.md")"
# prompt-brief loads on an ambiguous ask; when the router loads it, the brief must not add a round trip.
run_test "regression: prompt-brief is model-invocable for ambiguous asks" "" "$(awk -F ': ' '$1 == "disable-model-invocation" { print $2; exit }' "$PACK/skills/prompt-brief/SKILL.md")"
run_test "regression: router-loaded prompt-brief continues instead of stopping" "1" "$(grep -c 'por un pedido ambiguo | Muestra el brief al inicio del reporte y \*\*sigue\*\*' "$PACK/skills/prompt-brief/SKILL.md" || true)"
run_test "regression: router gates ambiguous asks through prompt-brief before other skills" "1" "$(grep -c 'carga `prompt-brief` \*\*antes de cualquier otra skill\*\*' "$PACK/skills/bridle-harness/SKILL.md" || true)"
run_test "regression: router reports once, at the end, in the charter block order" "1" "$(grep -c 'prueba (comando y exit code), riesgo no' "$PACK/skills/bridle-harness/SKILL.md" || true)"
run_test "regression: the report does not load asd-ste100 (router carries the rules)" "1" "$(grep -c 'No cargues' "$PACK/skills/bridle-harness/SKILL.md" || true)"
run_test "regression: the report uses the language of the user's last message" "1" "$(grep -c 'idioma del último mensaje del' "$PACK/skills/bridle-harness/SKILL.md" || true)"
run_test "regression: Spanish skills do not set the report language" "1" "$(grep -c 'eso no fija el idioma' "$PACK/skills/bridle-harness/SKILL.md" || true)"
run_test "regression: the brief follows the user's language, not the skill's" "1" "$(grep -c 'no en el de esta skill' "$PACK/skills/prompt-brief/SKILL.md" || true)"
run_test "regression: brief template labels translate with the user's language" "1" "$(grep -c 'Los rótulos se traducen al idioma del usuario' "$PACK/skills/prompt-brief/SKILL.md" || true)"
run_test "regression: asd-ste100 names the status report shape and its faults" "1" "$(grep -c '^## Status Reports' "$PACK/skills/asd-ste100/SKILL.md" || true)"
run_test "regression: charter forbids closing offers and trailing questions" "1" "$(grep -c 'no closing offer or question. .*State an assumption. Do not ask it.' "$PACK/rules/charter.txt" || true)"
run_test "regression: a bug fix adds a new regression test instead of renaming one" "1" "$(grep -c 'never rename an existing one' "$PACK/rules/testing.mdc" || true)"
run_test "regression: a bug found outside the ask goes to unverified risk, not the diff" "1" "$(grep -c 'fuera del pedido no entra al diff' "$PACK/skills/bridle-harness/SKILL.md" || true)"
run_test "regression: the report ends at the last block" "1" "$(grep -c 'El reporte termina en el último bloque' "$PACK/skills/bridle-harness/SKILL.md" || true)"
run_test "regression: router creates a grounded AGENTS.md when the repo has none" "1" "$(grep -c 'Si el repo no tiene `AGENTS.md`,' "$PACK/skills/bridle-harness/SKILL.md" || true)"

# The instruction order is written once, in the charter's Session list.
CHARTER_AUTH="$(awk '
  /^## Session$/ { p=1; next }
  p && /^## / { exit }
  p && /^[0-9]+\. / { print }
' "$PACK/rules/charter.txt")"
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
ROUTER="$PACK/skills/bridle-harness/SKILL.md"
RESULT="$(grep -q 'SECURITY.md' "$ROUTER" && echo restated || echo ok)"
run_test "regression: bridle-harness does not restate the instruction order" "ok" "$RESULT"
RESULT="$(grep -q 'turn-check' "$ROUTER" && echo stale || echo ok)"
run_test "regression: bridle-harness does not name the Cursor stop turn-check" "ok" "$RESULT"
ROUTE_OK=ok
while IFS= read -r skill; do
  case "$skill" in ''|bridle-harness) continue ;; esac
  grep -q "\`$skill\`" "$ROUTER" || ROUTE_OK="unrouted:$skill"
done < <(manifest_list '.skills[]')
run_test "bridle-harness routes every catalog skill" "ok" "$ROUTE_OK"
# An always-trigger description loads the skill on unrelated asks and widens the diff.
ALWAYS_OK=ok
while IFS= read -r skill; do
  [[ -n "$skill" ]] || continue
  awk '/^---$/{c++; next} c==1' "$PACK/skills/$skill/SKILL.md" | grep -q 'SIEMPRE' && ALWAYS_OK="always:$skill"
done < <(manifest_list '.skills[]')
run_test "regression: engineering skills do not trigger SIEMPRE" "ok" "$ALWAYS_OK"

LOC_OK=1
for f in "$PACK"/hooks/before_submit_prompt.sh "$PACK"/hooks/before_shell.sh "$PACK"/hooks/before_read_file.sh; do
  n="$(wc -l < "$f")"
  [[ "$n" -le 80 ]] || { LOC_OK=0; break; }
done
run_test "event hooks LOC ≤ 80" "1" "$LOC_OK"

if ! grep -Rq --include='*.sh' 'updated_input' "$PACK/hooks/" "$PACK/hosts/" 2>/dev/null; then UP=ok; else UP=fail; fi
run_test "no updated_input in hooks" "ok" "$UP"

B_HITS="$(grep -Rn --include='*.sh' --include='*.txt' -F '\b' "$PACK/hooks" "$PACK/hosts" 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
RESULT="$([[ -z "$B_HITS" ]] && echo ok || echo fail)"
run_test "hooks have zero GNU grep \\b (macOS BSD-safe)" "ok" "$RESULT"

RESULT="$(echo '{"command":"seq 1 400 > src/big.ts","cwd":"/tmp"}' | bash "$PACK/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "pre-action gate: shell redirect into .ts denied before write" "deny" "$RESULT"

RESULT="$(echo '{"command":"bash tests/run.sh && bash scripts/scope_eval.sh check","cwd":"/tmp"}' | bash "$PACK/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "pre-action gate: repo proof command allowed" "allow" "$RESULT"

[[ -e "$PACK/hooks/lib/host.sh" ]] && HOSTLIB=present || HOSTLIB=absent
run_test "regression: pack does not ship lib/host.sh" "absent" "$HOSTLIB"
RESULT="$(echo '{"command":"git push --force origin main","cwd":"/tmp"}' | CLAUDE_PROJECT_DIR=/tmp bash "$PACK/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "regression: the host is never inferred from the environment; unset BRIDLE_HOST emits Cursor JSON" "deny" "$RESULT"

CHARTER="$PACK/rules/charter.txt"
if grep -qE 'Never above|useEffect|failClosed|globs:' "$CHARTER"; then CHARTER_DUP=fail; else CHARTER_DUP=ok; fi
run_test "regression: charter does not restate core.mdc or hook internals" "ok" "$CHARTER_DUP"

CHARTER_COPIES="$(grep -Rnl 'You are kleosr'"'"'s engineering partner' "$PACK/rules" "$PACK/skills" "$PACK/agents" "$PACK/hooks" "$PACK/hosts" "$PACK/AGENTS.md" "$PACK/docs" 2>/dev/null | wc -l | tr -d ' ')"
run_test "regression: charter body has one copy in the pack" "1" "$CHARTER_COPIES"
if grep -q 'Observability is command' "$CHARTER"; then CHARTER_DRIFT=fail; else CHARTER_DRIFT=ok; fi
run_test "regression: paste stays the thin charter (no settings-copy essay)" "ok" "$CHARTER_DRIFT"

if grep -q '## First reads' "$PACK/AGENTS.md"; then READS=fail; else READS=ok; fi
run_test "regression: AGENTS.md does not mandate a first-read stack" "ok" "$READS"
AGENTS_N="$(wc -l < "$PACK/AGENTS.md" | tr -d ' ')"
run_test "AGENTS.md is a directory page (≤120 lines)" "ok" "$([[ "$AGENTS_N" -le 120 ]] && echo ok || echo "lines:$AGENTS_N")"

# Every request carries these bytes; the cap is the ratchet from the context cut.
ON_BYTES="$(cat "$PACK/rules/charter.txt" "$PACK/rules/core.mdc" "$PACK/rules/testing.mdc" | wc -c | tr -d ' ')"
run_test "always-on charter+core+testing stay within 8192 bytes" "ok" "$([[ "$ON_BYTES" -le 8192 ]] && echo ok || echo "bytes:$ON_BYTES")"

