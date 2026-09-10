#!/usr/bin/env bash
# Doctor: pack inventory + isolated fixture install + optional live checksum.
# Modes (same script; fixture is not proof of live):
#   default:               pack + isolated fixture + optional live checksum
#   DOCTOR_SKIP_FIXTURE=1  pack + live only (read-only live diagnosis)
#   DOCTOR_SKIP_LIVE=1     pack + fixture only; live ~/.cursor is not verified
# Tests set HOME to an isolated temp dir; only an operator run without a
# HOME override touches the real installation.
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$PACK/shared/hooks"
FAIL=0

# shellcheck source=shared/hooks/lib/fleet_scan.sh
source "$PACK/shared/hooks/lib/fleet_scan.sh"

ok() { echo "[ok] $1"; }
fail() { echo "[fail] $1"; FAIL=1; }

if [[ "${DOCTOR_SKIP_LIVE:-0}" == "1" ]]; then
  echo "[info] live ~/.cursor will not be verified (DOCTOR_SKIP_LIVE=1)"
fi

if [[ "${BASH_VERSINFO[0]:-0}" -ge 3 ]]; then ok "bash >= 3.2 (${BASH_VERSION})"
else fail "bash >= 3.2 required (found ${BASH_VERSION:-unknown})"; fi

if command -v jq >/dev/null 2>&1; then ok "jq $(jq --version 2>/dev/null || echo 'present')"
else fail "jq not found — required for JSON parsing in hooks"; fi

if command -v shellcheck >/dev/null 2>&1; then ok "shellcheck available"
else echo "[warn] shellcheck not found (optional, recommended for CI)"; fi

for f in "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/lib/*.sh "$PACK"/scripts/*.sh; do
  [[ -f "$f" ]] || continue
  if [[ -x "$f" ]]; then ok "executable: ${f#$PACK/}"
  else fail "not executable: ${f#$PACK/}"; fi
done

for j in "$HOOKS_DIR/hooks.json" "$HOOKS_DIR/hooks.cloud.json" "$PACK/shared/config/manifest.json" "$PACK/package.json"; do
  if jq empty "$j" 2>/dev/null; then ok "valid JSON: ${j#$PACK/}"
  else fail "invalid JSON: ${j#$PACK/}"; fi
done

if [[ -f "$HOOKS_DIR/policy/secret_paths.ere" && -f "$HOOKS_DIR/policy/secret_tokens.ere" ]]; then
  ok "secret policy files present"
else fail "secret policy files missing"; fi

if ! grep -Rq --include='*.sh' 'updated_input' "$HOOKS_DIR/" 2>/dev/null; then ok "no updated_input in hooks"
else fail "updated_input found in hooks (banned)"; fi

GNU_HITS="$(grep -Rn --include='*.sh' -E 'flock|mapfile|readlink -f|stat -c' "$HOOKS_DIR/" 2>/dev/null \
  | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
if [[ -z "$GNU_HITS" ]]; then ok "no GNU-only utils in hooks (macOS safe)"
else fail "GNU-only util found in hooks: $GNU_HITS"; fi

for f in "$HOOKS_DIR"/before_submit_prompt.sh "$HOOKS_DIR"/before_shell.sh "$HOOKS_DIR"/before_read_file.sh "$HOOKS_DIR"/stop.sh; do
  n="$(wc -l < "$f")"
  if [[ "$n" -le 80 ]]; then ok "LOC ≤ 80: ${f#$PACK/} ($n)"
  else fail "LOC > 80: ${f#$PACK/} ($n)"; fi
done

for d in shared/hooks shared/hooks/lib shared/hooks/policy shared/rules shared/skills shared/agents shared/config docs scripts tests; do
  if [[ -d "$PACK/$d" ]]; then ok "dir exists: $d/"
  else fail "missing dir: $d/"; fi
done

while IFS= read -r cmd; do
  cmd="${cmd%$'\r'}"
  [[ -z "$cmd" ]] && continue
  script="${cmd#./hooks/}"
  script="${script%% *}"
  if [[ -f "$HOOKS_DIR/$script" ]]; then ok "hook ref exists: $script"
  else fail "hook ref missing: $script (from hooks.json)"; fi
done < <(jq -r '.hooks | to_entries[] | .value[]? | .command // empty' "$HOOKS_DIR/hooks.json" 2>/dev/null || true)

if grep -q '^state/' "$PACK/.gitignore" && grep -q '\.cursor/' "$PACK/.gitignore"; then ok ".gitignore covers state/ and .cursor/"
else fail ".gitignore missing state/ or .cursor/ coverage"; fi

if [[ "${DOCTOR_SKIP_FIXTURE:-0}" != "1" ]]; then
DOCTOR_FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/kleos-doctor.XXXXXX")"
if HOME="$DOCTOR_FIXTURE" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 \
  && grep -q 'hooks/before_submit_prompt.sh' "$DOCTOR_FIXTURE/.cursor/hooks.json" 2>/dev/null; then
  ok "fixture install: hooks.json registers beforeSubmitPrompt (isolated HOME)"
else
  fail "fixture install failed or hooks.json missing beforeSubmitPrompt"
fi
if [[ -d "$DOCTOR_FIXTURE/.cursor/hooks" ]]; then
  for rel in before_submit_prompt.sh before_shell.sh before_read_file.sh stop.sh lib/common.sh lib/shell_gate.sh lib/diff_gate.sh; do
    if [[ -f "$DOCTOR_FIXTURE/.cursor/hooks/$rel" ]]; then
      ok "fixture install: hooks/$rel present"
    else
      fail "fixture install: hooks/$rel missing"
    fi
  done
fi
if [[ -f "$DOCTOR_FIXTURE/.cursor/rules/types.mdc" ]]; then
  ok "fixture install: types.mdc in user rules"
else
  fail "fixture install: types.mdc missing from user rules"
fi
rm -rf "$DOCTOR_FIXTURE"
fi

if [[ "${DOCTOR_SKIP_LIVE:-0}" != "1" ]]; then
if grep -qE 'hooks/before_submit_prompt\.sh' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
  ok "live: ~/.cursor has kleosrules beforeSubmitPrompt (optional — not required in CI/agent env)"
else
  echo "[info] live: ~/.cursor not a kleosrules install (expected in agent/CI env; run FORCE=1 bash scripts/install.sh)"
fi
fi

if jq -e '.hooks.beforeSubmitPrompt[0].command == "./hooks/before_submit_prompt.sh"' "$HOOKS_DIR/hooks.json" >/dev/null 2>&1 \
  && jq -e '.hooks.beforeShellExecution[0].command == "./hooks/before_shell.sh"' "$HOOKS_DIR/hooks.json" >/dev/null 2>&1 \
  && jq -e '.hooks.beforeReadFile[0].command == "./hooks/before_read_file.sh"' "$HOOKS_DIR/hooks.json" >/dev/null 2>&1 \
  && jq -e '.hooks.stop[0].command == "./hooks/stop.sh" and .hooks.stop[0].loop_limit == 1' "$HOOKS_DIR/hooks.json" >/dev/null 2>&1 \
  && jq -e '.hooks|has("sessionStart")|not' "$HOOKS_DIR/hooks.json" >/dev/null 2>&1 \
  && jq -e '.hooks.beforeSubmitPrompt[0].failClosed == true and .hooks.beforeShellExecution[0].failClosed == true and .hooks.beforeReadFile[0].failClosed == true' "$HOOKS_DIR/hooks.json" >/dev/null 2>&1 \
  && jq -e '.hooks.beforeSubmitPrompt[0].failClosed == true and .hooks.beforeShellExecution[0].failClosed == true' "$HOOKS_DIR/hooks.cloud.json" >/dev/null 2>&1; then
  ok "hooks.json registers submit+shell+read+stop (no sessionStart; security failClosed)"
else fail "hooks.json must register submit+shell+read+stop with ./hooks/ commands, stop.loop_limit 1, no sessionStart, and security failClosed"; fi

if jq empty "$PACK/shared/config/manifest.json" >/dev/null 2>&1 \
  && [[ -f "$HOOKS_DIR/lib/hooks_json.jq" && -f "$HOOKS_DIR/lib/hooks_json.sh" ]]; then
  ok "manifest.json + hooks_json merge/strip present"
else fail "manifest.json or hooks_json merge helpers missing"; fi

if [[ -e "$PACK/.cursor/hooks.json" || -d "$PACK/.cursor/hooks" ]]; then
  fail "pack has repo-level hooks (never install into this pack)"
else ok "no repo-level hooks in pack (local global-only mode)"; fi

if ! grep -RqiE 'CallMcpTool' "$HOOKS_DIR/" --include='*.sh' 2>/dev/null; then ok "no MCP core dependency in hooks"
else fail "MCP core dependency found in hooks (should be optional, not core)"; fi

if [[ -f "$PACK/SECURITY.md" ]]; then ok "SECURITY.md present"
else fail "SECURITY.md missing"; fi

LAW_STALE=""
for f in "$PACK/shared/rules/agent.mdc" "$PACK/shared/rules/ponytail.mdc" \
  "$PACK/shared/rules/vibe.mdc" "$PACK/shared/rules/postgres.mdc" \
  "$PACK/shared/rules/supabase.mdc" \
  "$PACK/shared/rules/next.mdc" "$PACK/shared/rules/vite.mdc" \
  "$PACK/shared/rules/astro.mdc" "$PACK/shared/rules/complexity.mdc" \
  "$PACK/shared/rules/pnpm.mdc" "$PACK/shared/rules/testing.mdc" \
  "$PACK/shared/rules/types.mdc" \
  "$PACK/shared/rules/USER-RULES.paste.txt"; do
  [[ -f "$f" ]] || { LAW_STALE="$LAW_STALE missing:${f#$PACK/}"; continue; }
  if grep -qE 'stop_gate|lean_gate|post_tool_use|pre_tool_use|before_mcp' "$f"; then
    LAW_STALE="$LAW_STALE ${f#$PACK/}"
  fi
done
if [[ -z "$LAW_STALE" ]]; then ok "law matches four-hook harness (no stale gate names)"
else fail "stale deleted-hook names in$LAW_STALE"; fi

if grep -q 'hard 300' "$PACK/shared/rules/ponytail.mdc" && grep -q 'never 500' "$PACK/shared/rules/ponytail.mdc"; then ok "ponytail.mdc has hard 300 roof and never-500 ceiling"
else fail "ponytail.mdc missing hard 300 roof or never-500 ceiling"; fi

if grep -q '^alwaysApply: true' "$PACK/shared/rules/types.mdc" \
  && grep -q '^alwaysApply: true' "$PACK/shared/rules/testing.mdc"; then ok "types.mdc and testing.mdc are alwaysApply"
else fail "types.mdc or testing.mdc is not alwaysApply"; fi

if grep -q 'Never above \*\*22\*\*' "$PACK/shared/rules/complexity.mdc"; then ok "complexity.mdc has the cyclo-22 ceiling"
else fail "complexity.mdc missing cyclo-22 ceiling"; fi

PASTE="$PACK/shared/rules/USER-RULES.paste.txt"
PASTE_HEADS=ok
for h in Identity Stance Autonomy Mission Session Retrieval Host; do
  grep -q "## $h" "$PASTE" || PASTE_HEADS="missing:$h"
done
if [[ "$PASTE_HEADS" == ok ]]; then ok "USER-RULES.paste.txt keeps charter headings"
else fail "USER-RULES.paste.txt missing charter heading ($PASTE_HEADS)"; fi

if grep -qE 'rm -rf "\$HOME_C/hooks"' "$PACK/scripts/uninstall.sh" \
  || grep -qE 'rm -f "\$HOME_C/hooks.json"' "$PACK/scripts/uninstall.sh"; then
  fail "uninstall.sh must not wipe ~/.cursor/hooks.json or hooks/ wholesale"
else ok "uninstall.sh does not wholesale-delete hooks.json or hooks/"
fi

REF_BAD=""
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  [[ -f "$PACK/shared/rules/${name}.mdc" ]] || REF_BAD="$REF_BAD missing-rule:$name"
done < <(load_lines "$PACK/shared/config/rules.global.txt")
while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  [[ -f "$PACK/shared/skills/$skill/SKILL.md" ]] || REF_BAD="$REF_BAD missing-skill:$skill"
done < <(load_lines "$PACK/shared/config/skills.txt")
while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  [[ -d "$PACK/shared/skills/$skill" ]] && REF_BAD="$REF_BAD retired-present:$skill"
done < <(load_lines "$PACK/shared/config/retired-skills.txt")
if [[ -z "$REF_BAD" ]]; then ok "rule/skill references resolve"
else fail "unresolved references:$REF_BAD"; fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  if [[ "${DOCTOR_SKIP_LIVE:-0}" == "1" ]]; then
    echo "=== CHECKOUT CHECKS PASSED ==="
    echo "[info] live ~/.cursor was not verified (DOCTOR_SKIP_LIVE=1). Unset that flag to checksum the active install."
  else
    echo "=== ALL CHECKS PASSED ==="
  fi
  exit 0
else
  echo "=== SOME CHECKS FAILED ==="
  exit 1
fi
