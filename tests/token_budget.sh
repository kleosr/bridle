#!/usr/bin/env bash
# Always-on token budget. Caps are after the lean rewrite. Fail if someone
# adds an alwaysApply rule, fattens paste/agent.mdc, or dumps NOW.md again.

bytes_of() { wc -c < "$1" | tr -d ' '; }

tok_est() {
  local n="$1"
  echo $(( (n + 3) / 4 ))
}

le_cap() {
  local got="$1" cap="$2"
  if [[ "$got" -le "$cap" ]]; then echo ok; else echo "$got>$cap"; fi
}

ALWAYS_APPLY_COUNT_MAX=7
ALWAYS_APPLY_BYTES_MAX=8200
AGENT_MDC_BYTES_MAX=1900
PASTE_BYTES_MAX=3900
AGENTS_MD_BYTES_MAX=2400
SESSION_INJECT_BYTES_MAX=220
ALWAYS_ON_SESSION_BYTES_MAX=12500
PASTE_ROOF_PARA_BYTES_MAX=480
SKILL_DESC_BYTES_MAX=200
SKILL_BODY_BYTES_MAX=1800
SKILL_BODY_SUM_MAX=12000
HUNTER_BYTES_MAX=2500
CUT_BYTES_MAX=2300
PROVE_BYTES_MAX=2300
README_BYTES_MAX=3200

COUNT=0
MDC_BYTES=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  COUNT=$((COUNT + 1))
  n="$(bytes_of "$f")"
  MDC_BYTES=$((MDC_BYTES + n))
  echo "  alwaysApply $(basename "$f")  $n B  ~$(tok_est "$n") tok"
done < <(grep -l '^alwaysApply: true' "$PACK"/shared/rules/*.mdc | sort)

PASTE="$PACK/shared/rules/USER-RULES.paste.txt"
PASTE_B="$(bytes_of "$PASTE")"
AGENTS_B="$(bytes_of "$PACK/AGENTS.md")"
AGENT_B="$(bytes_of "$PACK/shared/rules/agent.mdc")"

CTX="$(cat "$PACK/tests/fixtures/sessionStart.json" | bash "$PACK/shared/hooks/session_start.sh" | jq -r '.additional_context // empty')"
INJECT_B="$(printf '%s' "$CTX" | wc -c | tr -d ' ')"
SESSION_B=$((PASTE_B + MDC_BYTES + INJECT_B))

echo "  paste               $PASTE_B B  ~$(tok_est "$PASTE_B") tok"
echo "  AGENTS.md           $AGENTS_B B  ~$(tok_est "$AGENTS_B") tok"
echo "  sessionStart inject $INJECT_B B  ~$(tok_est "$INJECT_B") tok"
echo "  alwaysApply sum     $MDC_BYTES B  ~$(tok_est "$MDC_BYTES") tok"
echo "  session always-on   $SESSION_B B  ~$(tok_est "$SESSION_B") tok  (paste+mdc+inject)"

run_test "always-on rule count is $ALWAYS_APPLY_COUNT_MAX" "$ALWAYS_APPLY_COUNT_MAX" "$COUNT"
run_test "alwaysApply bytes ≤ $ALWAYS_APPLY_BYTES_MAX" "ok" "$(le_cap "$MDC_BYTES" "$ALWAYS_APPLY_BYTES_MAX")"
run_test "agent.mdc bytes ≤ $AGENT_MDC_BYTES_MAX" "ok" "$(le_cap "$AGENT_B" "$AGENT_MDC_BYTES_MAX")"
run_test "paste bytes ≤ $PASTE_BYTES_MAX" "ok" "$(le_cap "$PASTE_B" "$PASTE_BYTES_MAX")"
run_test "AGENTS.md bytes ≤ $AGENTS_MD_BYTES_MAX" "ok" "$(le_cap "$AGENTS_B" "$AGENTS_MD_BYTES_MAX")"
run_test "sessionStart inject bytes ≤ $SESSION_INJECT_BYTES_MAX" "ok" "$(le_cap "$INJECT_B" "$SESSION_INJECT_BYTES_MAX")"
run_test "always-on session bytes ≤ $ALWAYS_ON_SESSION_BYTES_MAX" "ok" "$(le_cap "$SESSION_B" "$ALWAYS_ON_SESSION_BYTES_MAX")"

PNPM_AA="$(awk '/^alwaysApply:/{print $2; exit}' "$PACK/shared/rules/pnpm.mdc")"
run_test "pnpm.mdc stays alwaysApply (glob fire is not observable here)" "true" "$PNPM_AA"

ROOF_PARA="$(awk '/^Quality roofs/{p=1} p{print} p && /^$/{exit}' "$PASTE")"
ROOF_B="$(printf '%s' "$ROOF_PARA" | wc -c | tr -d ' ')"
echo "  paste roof para     $ROOF_B B  ~$(tok_est "$ROOF_B") tok"
run_test "paste roof restatement bytes ≤ $PASTE_ROOF_PARA_BYTES_MAX" "ok" "$(le_cap "$ROOF_B" "$PASTE_ROOF_PARA_BYTES_MAX")"

ROOF_LABEL=ok
printf '%s' "$ROOF_PARA" | grep -qi 'restatement' || ROOF_LABEL="missing-label"
printf '%s' "$ROOF_PARA" | grep -q 'complexity.mdc' || ROOF_LABEL="missing-complexity"
printf '%s' "$ROOF_PARA" | grep -q 'ponytail.mdc' || ROOF_LABEL="missing-ponytail"
printf '%s' "$ROOF_PARA" | grep -q 'testing.mdc' || ROOF_LABEL="missing-testing"
printf '%s' "$ROOF_PARA" | grep -q 'types.mdc' || ROOF_LABEL="missing-types"
run_test "paste roof paragraph is a labeled restatement of the four .mdc files" "ok" "$ROOF_LABEL"

DUMP=ok
printf '%s' "$CTX" | grep -q '## Now' && DUMP="dumped-now"
printf '%s' "$CTX" | grep -q 'Session file is' && DUMP="dumped-body"
printf '%s' "$CTX" | grep -q 'NOW.md' || DUMP="missing-path"
run_test "sessionStart injects NOW.md path, not NOW body" "ok" "$DUMP"

VERBATIM=ok
grep -q 'Code you write must pass complexity lint' "$PASTE" && VERBATIM="complexity-body"
grep -q 'Cero bloat en tests' "$PASTE" && VERBATIM="testing-body"
grep -q 'Silent on untyped files' "$PASTE" && VERBATIM="types-body"
grep -q 'Escape hatch = design bug' "$PASTE" && VERBATIM="types-hatch"
run_test "paste does not copy roof .mdc bodies (cloud floor numbers only)" "ok" "$VERBATIM"

SK_OK=ok
while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  f="$PACK/shared/skills/$skill/SKILL.md"
  [[ -f "$f" ]] || { SK_OK="missing:$skill"; break; }
  d="$(awk '
    BEGIN { d=0; n=0 }
    /^description:[[:space:]]*>/ { d=1; next }
    d && /^[^[:space:]]/ { exit }
    d { n += length($0) + 1 }
    END { print n+0 }
  ' "$f")"
  echo "  skill desc $skill  $d B  ~$(tok_est "$d") tok"
  if [[ "$d" -gt "$SKILL_DESC_BYTES_MAX" ]]; then
    SK_OK="fat:$skill:$d"
    break
  fi
done < <(grep -v '^#' "$PACK/shared/config/skills.txt" | grep -v '^[[:space:]]*$')
run_test "skill descriptions stay tight routers (≤ $SKILL_DESC_BYTES_MAX B)" "ok" "$SK_OK"

SK_BODY_SUM=0
SK_BODY_OK=ok
while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  f="$PACK/shared/skills/$skill/SKILL.md"
  b="$(bytes_of "$f")"
  SK_BODY_SUM=$((SK_BODY_SUM + b))
  echo "  skill body $skill  $b B  ~$(tok_est "$b") tok"
  if [[ "$b" -gt "$SKILL_BODY_BYTES_MAX" ]]; then
    SK_BODY_OK="fat:$skill:$b"
    break
  fi
done < <(grep -v '^#' "$PACK/shared/config/skills.txt" | grep -v '^[[:space:]]*$')
echo "  skill body sum     $SK_BODY_SUM B  ~$(tok_est "$SK_BODY_SUM") tok"
run_test "each skill body ≤ $SKILL_BODY_BYTES_MAX B" "ok" "$SK_BODY_OK"
run_test "skill body sum ≤ $SKILL_BODY_SUM_MAX" "ok" "$(le_cap "$SK_BODY_SUM" "$SKILL_BODY_SUM_MAX")"

HUNTER_B="$(bytes_of "$PACK/shared/agents/hunter.md")"
CUT_B="$(bytes_of "$PACK/shared/agents/cut.md")"
PROVE_B="$(bytes_of "$PACK/shared/agents/prove.md")"
README_B="$(bytes_of "$PACK/README.md")"
echo "  hunter.md           $HUNTER_B B  ~$(tok_est "$HUNTER_B") tok"
echo "  cut.md              $CUT_B B  ~$(tok_est "$CUT_B") tok"
echo "  prove.md            $PROVE_B B  ~$(tok_est "$PROVE_B") tok"
echo "  README.md           $README_B B  ~$(tok_est "$README_B") tok"
run_test "hunter.md bytes ≤ $HUNTER_BYTES_MAX" "ok" "$(le_cap "$HUNTER_B" "$HUNTER_BYTES_MAX")"
run_test "cut.md bytes ≤ $CUT_BYTES_MAX" "ok" "$(le_cap "$CUT_B" "$CUT_BYTES_MAX")"
run_test "prove.md bytes ≤ $PROVE_BYTES_MAX" "ok" "$(le_cap "$PROVE_B" "$PROVE_BYTES_MAX")"
run_test "README.md bytes ≤ $README_BYTES_MAX" "ok" "$(le_cap "$README_B" "$README_BYTES_MAX")"

LAYOUT=ok
[[ -f "$PACK/docs/_archive/README.md" ]] || LAYOUT="missing-archive-index"
[[ -f "$PACK/docs/README.md" ]] || LAYOUT="missing-docs-index"
[[ -f "$PACK/docs/engineering-rules-audit.md" ]] && LAYOUT="audit-not-archived"
[[ -f "$PACK/docs/research/agent-instructions-research.md" ]] && LAYOUT="research-not-archived"
run_test "docs layout: living index + _archive, old audit paths gone" "ok" "$LAYOUT"

SOURCE_OK=ok
[[ -f "$PACK/shared/skills/premium-ui-craft/SOURCE.md" ]] || SOURCE_OK="missing-premium-SOURCE"
[[ -f "$PACK/shared/skills/landing-page-design/SOURCE.md" ]] || SOURCE_OK="missing-landing-SOURCE"
[[ -f "$PACK/shared/skills/redesign-existing-projects/SOURCE.md" ]] || SOURCE_OK="missing-redesign-SOURCE"
[[ -e "$PACK/shared/skills/premium-ui-craft/sources.md" ]] && SOURCE_OK="legacy-sources-md"
run_test "design skills use SOURCE.md (not sources.md)" "ok" "$SOURCE_OK"
