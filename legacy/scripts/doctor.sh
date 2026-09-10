#!/usr/bin/env bash
set -euo pipefail
# Doctor modes (same script). Fixture is not proof of live.
#   default: pack inventory + isolated fixture install + optional live checksum
#   DOCTOR_SKIP_FIXTURE=1 — pack + live only (read-only live diagnosis)
#   DOCTOR_SKIP_LIVE=1 — pack + fixture only; live ~/.cursor is not verified
# Tests set HOME to an isolated temp dir and never touch the real installation unless
# the operator runs doctor without HOME override.

PACK="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$PACK/shared/hooks"
FAIL=0

ok() { echo "[ok] $1"; }
fail() { echo "[fail] $1"; FAIL=1; }

if [[ "${DOCTOR_SKIP_LIVE:-0}" == "1" ]]; then
  echo "[info] live ~/.cursor will not be verified (DOCTOR_SKIP_LIVE=1)"
fi

if [[ "${BASH_VERSINFO[0]:-0}" -ge 3 ]]; then ok "bash >= 3.2 (${BASH_VERSION})"
else fail "bash >= 3.2 required (found ${BASH_VERSION:-unknown})"; fi

if command -v jq >/dev/null 2>&1; then ok "jq $(jq --version 2>/dev/null || echo 'present')"
else fail "jq not found — required for JSON parsing in hooks (brew install jq)"; fi

if command -v shellcheck >/dev/null 2>&1; then ok "shellcheck available"
else echo "[warn] shellcheck not found (optional, recommended for CI)"; fi

for f in "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/lib/*.sh "$PACK"/MacOS/install.sh "$PACK"/Linux/install.sh; do
  [[ -f "$f" ]] || continue
  if [[ -x "$f" ]]; then ok "executable: ${f#$PACK/}"
  else fail "not executable: ${f#$PACK/}"; fi
done

if jq empty "$HOOKS_DIR/hooks.json" 2>/dev/null; then ok "shared/hooks/hooks.json valid JSON"
else fail "shared/hooks/hooks.json invalid JSON"; fi

if jq empty "$HOOKS_DIR/hooks.cloud.json" 2>/dev/null; then ok "shared/hooks/hooks.cloud.json valid JSON"
else fail "shared/hooks/hooks.cloud.json invalid JSON"; fi

if [[ ! -f "$HOOKS_DIR/policy/lean.json" && ! -f "$HOOKS_DIR/policy/intent.json" ]]; then ok "no leftover lean/intent json"
else fail "leftover lean.json or intent.json still in policy/"; fi

POLICY_JSON="$(find "$HOOKS_DIR/policy" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$POLICY_JSON" -eq 0 ]]; then ok "policy has zero json (hooks do not read json policy)"
else fail "policy json count = $POLICY_JSON (expected 0)"; fi

if [[ -f "$HOOKS_DIR/policy/secret_paths.ere" ]]; then ok "secret_paths.ere present"
else fail "secret_paths.ere missing"; fi

if [[ -f "$HOOKS_DIR/policy/secret_tokens.ere" ]]; then ok "secret_tokens.ere present"
else fail "secret_tokens.ere missing"; fi

if [[ ! -f "$HOOKS_DIR/policy/mcp_deny.ere" && ! -f "$HOOKS_DIR/policy/destructive.ere" && ! -f "$HOOKS_DIR/policy/vernacular_bans.txt" ]]; then ok "unused policy files removed"
else fail "unused policy files still on disk"; fi

if [[ ! -e "$HOOKS_DIR/kleos-gate" && ! -e "$HOOKS_DIR/bin/kleos-gate" ]]; then ok "no Rust kleos-gate"
else fail "Rust kleos-gate detected — should be removed"; fi

if ! grep -Rq --include='*.sh' 'updated_input' "$HOOKS_DIR/" 2>/dev/null; then ok "no updated_input in hooks"
else fail "updated_input found in hooks (banned)"; fi

# lib/common.sh is the sanctioned platform shim (guarded stat branch); comments exempt.
GNU_HITS="$(grep -Rn --include='*.sh' -E 'flock|mapfile|readlink -f|stat -c' "$HOOKS_DIR/" 2>/dev/null \
  | grep -vE ':[0-9]+:[[:space:]]*#' | grep -v 'lib/common\.sh' || true)"
if [[ -z "$GNU_HITS" ]]; then ok "no GNU-only utils in hooks (macOS safe)"
else fail "GNU-only util found in hooks: $GNU_HITS"; fi

B_HITS="$(grep -Rn --include='*.sh' --include='*.txt' -F '\b' "$HOOKS_DIR/" 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
if [[ -z "$B_HITS" ]]; then ok "no GNU grep \\\\b (stock macOS BSD grep safe)"
else fail "GNU grep \\\\b found (breaks stock macOS): $B_HITS"; fi

for f in "$HOOKS_DIR"/before_submit_prompt.sh "$HOOKS_DIR"/before_shell.sh "$HOOKS_DIR"/before_read_file.sh "$HOOKS_DIR"/stop.sh; do
  n="$(wc -l < "$f")"
  if [[ "$n" -le 80 ]]; then ok "LOC ≤ 80: ${f#$PACK/} ($n)"
  else fail "LOC > 80: ${f#$PACK/} ($n)"; fi
done

for d in shared/hooks shared/hooks/lib shared/hooks/policy shared/rules shared/skills shared/config MacOS Linux Windows docs scripts tests; do
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

if grep -q '^state/' "$PACK/.gitignore" && grep -q '\.cursor/' "$PACK/.gitignore"; then ok "pack: .gitignore covers state/ and .cursor/"
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
  for rel in before_submit_prompt.sh before_shell.sh before_read_file.sh stop.sh lib/common.sh lib/shell_gate.sh lib/shell_fleet.sh lib/diff_gate.sh; do
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
if grep -qE 'hooks/before_submit_prompt\.sh|bash-shim\.ps1|wsl-shim\.ps1' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
  ok "live: ~/.cursor has kleosrules beforeSubmitPrompt (optional — not required in CI/agent env)"
else
  echo "[info] live: ~/.cursor not a kleosrules install (expected in agent/CI env; run FORCE=1 bash scripts/install.sh or Windows/install.ps1)"
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

if grep -q "stop.sh" "$PACK/Windows/install.ps1" && grep -q "diff_gate.sh" "$PACK/Windows/install.ps1"; then
  ok "Windows install copies stop.sh + diff_gate.sh"
else fail "Windows/install.ps1 missing stop.sh or diff_gate.sh (must match fleet_install.sh)"; fi

if grep -q "bash-shim.ps1" "$PACK/Windows/install.ps1" && [[ -f "$PACK/Windows/hooks/bash-shim.ps1" ]]; then
  ok "Windows Git Bash shim present"
else fail "Windows/install.ps1 must copy bash-shim.ps1 (Git Bash host; WSL fallback)"; fi

if grep -q "Remove-KleosRetiredSkills" "$PACK/Windows/install.ps1" && [[ -f "$PACK/Windows/lib/skills.ps1" ]]; then
  ok "Windows retired-skill cleanup helper present"
else fail "Windows/install.ps1 must call Remove-KleosRetiredSkills from lib/skills.ps1"; fi

if [[ -e "$PACK/.cursor/hooks.json" || -d "$PACK/.cursor/hooks" ]]; then
  fail "pack has repo-level hooks (never Lane-A into this pack)"
else ok "no repo-level hooks in pack (local global-only mode)"; fi

if ! grep -RqiE 'CallMcpTool|user-obsidian' "$HOOKS_DIR/" --include='*.sh' 2>/dev/null; then ok "no MCP core dependency in hooks"
else fail "MCP core dependency found in hooks (should be optional, not core)"; fi

if [[ -f "$PACK/SECURITY.md" ]] && grep -q 'onlyBuiltDependencies' "$PACK/SECURITY.md"; then ok "SECURITY.md present"
else fail "SECURITY.md missing or incomplete"; fi

if [[ ! -f "$PACK/HANDOFF.md" && ! -f "$PACK/NOW.md" && ! -d "$PACK/shared/skills/session-handoff" ]]; then ok "HANDOFF.md, NOW.md, and session-handoff retired"
else fail "HANDOFF.md / NOW.md / skills/session-handoff still on disk (retired)"; fi

if [[ ! -f "$HOOKS_DIR/stop_gate.sh" && ! -f "$HOOKS_DIR/lean_gate.sh" && ! -f "$HOOKS_DIR/pre_tool_use.sh" ]]; then
  ok "unregistered event scripts removed"
else fail "unregistered event scripts still on disk"; fi

LAW_STALE=""
for f in "$PACK/shared/rules/agent.mdc" "$PACK/shared/rules/ponytail.mdc" \
  "$PACK/shared/rules/vibe.mdc" "$PACK/shared/rules/postgres.mdc" \
  "$PACK/shared/rules/supabase.mdc" \
  "$PACK/shared/rules/next.mdc" "$PACK/shared/rules/vite.mdc" \
  "$PACK/shared/rules/astro.mdc" "$PACK/shared/rules/complexity.mdc" \
  "$PACK/shared/rules/pnpm.mdc" "$PACK/shared/rules/testing.mdc" \
  "$PACK/shared/rules/types.mdc" \
  "$PACK/shared/rules/USER-RULES.paste.txt" "$PACK/shared/skills/ponytail/SKILL.md" \
  "$PACK/shared/skills/testing/SKILL.md" \
  "$PACK/shared/skills/complexity/SKILL.md"; do
  [[ -f "$f" ]] || { LAW_STALE="$LAW_STALE missing:${f#$PACK/}"; continue; }
  if grep -qE 'stop_gate|lean_gate|post_tool_use|pre_tool_use|before_mcp' "$f"; then
    LAW_STALE="$LAW_STALE ${f#$PACK/}"
  fi
done
if [[ -z "$LAW_STALE" ]]; then ok "law/skills match four-hook harness (no deleted 2026-08 gate names)"
else fail "stale deleted-hook names in$LAW_STALE"; fi

if [[ ! -f "$PACK/shared/rules/native-lean-autoload.mdc" && ! -f "$PACK/shared/rules/debugging.mdc" ]]; then ok "merged/retired duplicate mdc gone"
else fail "native-lean-autoload.mdc or debugging.mdc still on disk"; fi

if grep -q 'hard 300' "$PACK/shared/rules/ponytail.mdc" && grep -q 'never 500' "$PACK/shared/rules/ponytail.mdc"; then ok "ponytail.mdc has hard 300 roof and never-500 ceiling"
else fail "ponytail.mdc missing hard 300 roof or never-500 ceiling"; fi

if grep -q '^alwaysApply: true' "$PACK/shared/rules/types.mdc" \
  && grep -q '^alwaysApply: true' "$PACK/shared/rules/testing.mdc"; then ok "types.mdc and testing.mdc are alwaysApply"
else fail "types.mdc or testing.mdc is not alwaysApply"; fi

if grep -q 'Never above \*\*22\*\*' "$PACK/shared/rules/complexity.mdc" \
  && grep -q 'Halstead difficulty' "$PACK/shared/rules/complexity.mdc" \
  && grep -q 'CRAP' "$PACK/shared/rules/complexity.mdc"; then ok "complexity.mdc has cyclo-22 ceiling plus cognitive/Halstead/CRAP"
else fail "complexity.mdc missing quality-roof numbers"; fi

PASTE="$PACK/shared/rules/USER-RULES.paste.txt"
PASTE_HEADS=ok
for h in Identity Stance Autonomy Mission Session Retrieval "Cursor + Grok"; do
  grep -q "## $h" "$PASTE" || PASTE_HEADS="missing:$h"
done
if [[ "$PASTE_HEADS" == ok ]] \
  && grep -q 'Quality roofs are only in `complexity.mdc`' "$PASTE" \
  && grep -q 'effective destination' "$PASTE" \
  && grep -q 'continuity evidence' "$PASTE"; then ok "USER-RULES.paste.txt keeps charter headings and roof pointers"
else fail "USER-RULES.paste.txt missing charter heading or roof pointer ($PASTE_HEADS)"; fi

if grep -q '^types$' "$PACK/shared/config/rules.global.txt" \
  && grep -q '^complexity$' "$PACK/shared/config/rules.global.txt" \
  && grep -q '^pnpm$' "$PACK/shared/config/rules.global.txt" \
  && grep -q '^supabase$' "$PACK/shared/config/rules.global.txt"; then ok "rules.global.txt includes types, complexity, pnpm, supabase"
else fail "rules.global.txt missing types, complexity, pnpm, or supabase"; fi

if [[ ! -f "$PACK/shared/rules/vernacular.mdc" && ! -d "$PACK/shared/skills/vernacular" ]]; then ok "vernacular retired"
else fail "vernacular.mdc or skills/vernacular still on disk"; fi

if [[ ! -f "$PACK/shared/rules/mario-engineering-team.mdc" ]]; then ok "mario-engineering-team retired"
else fail "mario-engineering-team.mdc still on disk"; fi

if [[ -f "$PACK/shared/rules/pnpm.mdc" && -f "$PACK/shared/agents/hunter.md" ]]; then ok "pnpm.mdc + hunter/cut/prove in pack"
else fail "pnpm.mdc or shared/agents/hunter.md missing"; fi

if [[ ! -f "$PACK/shared/rules/lean-code.mdc" && ! -d "$PACK/shared/skills/lean-code" ]]; then ok "no lean-code duplicate"
else fail "Duplicate found: lean-code (use ponytail instead)"; fi

if ! grep -RqE '(lean-code|codebase-memory|architecture-fitness|domain-architecture|improve-codebase-architecture|eval-pass|unconditional-counterexample|create-pr|git-commit|ship-loop|cursor-research|grill-me|harness-retro|design-taste-frontend|design-tokens|frontend-design|ui-structure|ui-ux-audit|formulary|no-hardcode|humanizer|system-wiring|workspace-scope|agents-map|benln-write|breakthrough-deepen)' "$HOOKS_DIR/fleet_sync.sh" "$PACK/shared/config/skills.txt" "$PACK/AGENTS.md" "$PACK/README.md" 2>/dev/null; then ok "no stale references to deleted skills"
else fail "Stale reference to deleted skill found in config files"; fi

hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 1
  fi
}
HOME_HOOKS="${HOME}/.cursor/hooks"
if [[ "${DOCTOR_SKIP_LIVE:-0}" != "1" ]] && grep -qE 'hooks/before_submit_prompt\.sh|bash-shim\.ps1|wsl-shim\.ps1' "${HOME}/.cursor/hooks.json" 2>/dev/null && [[ -d "$HOME_HOOKS" ]]; then
  if hash_file "$HOOKS_DIR/before_submit_prompt.sh" >/dev/null; then
    for rel in before_submit_prompt.sh before_shell.sh before_read_file.sh stop.sh lib/common.sh lib/shell_gate.sh lib/shell_fleet.sh lib/diff_gate.sh; do
      src="$HOOKS_DIR/$rel"
      dst="$HOME_HOOKS/$rel"
      if [[ ! -f "$dst" ]]; then
        fail "live install missing: ~/.cursor/hooks/$rel (run FORCE=1 bash scripts/install.sh)"
        continue
      fi
      hs="$(hash_file "$src")"
      hd="$(hash_file "$dst")"
      if [[ -n "$hs" && "$hs" == "$hd" ]]; then
        ok "live checksum match: $rel"
      else
        fail "live checksum drift ~/.cursor/hooks/$rel (run FORCE=1 bash scripts/install.sh)"
      fi
    done
  else
    echo "[warn] no shasum/sha256sum — skipping live hook checksum verification"
  fi
fi

if [[ "${DOCTOR_SKIP_LIVE:-0}" != "1" ]] && [[ -d "${HOME}/.cursor/skills" ]]; then
  leftover=0
  for d in "${HOME}/.cursor/skills"/*.pre-kleos-bak; do
    [[ -e "$d" || -L "$d" ]] || continue
    leftover=1
    break
  done
  if [[ "$leftover" -eq 1 ]]; then
    echo "[info] live: ~/.cursor/skills/*.pre-kleos-bak is cataloged by Cursor; re-run Windows/install.ps1 when approved"
  fi
fi

REF_BAD=""
# shellcheck source=shared/hooks/lib/fleet_scan.sh
source "$PACK/shared/hooks/lib/fleet_scan.sh"
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
if grep -q 'npx @next/codemod' "$PACK/shared/rules/next.mdc"; then REF_BAD="$REF_BAD next-npx"; fi
if grep -q 'supabase-postgres-best-practices' "$PACK/shared/rules/postgres.mdc"; then REF_BAD="$REF_BAD pg-supabase-skill"; fi
if grep -q 'vercel-react-best-practices' "$PACK/shared/rules/vibe.mdc" \
  && ! grep -qiE 'if (that skill is )?installed|if present' "$PACK/shared/rules/vibe.mdc"; then
  REF_BAD="$REF_BAD vibe-undeclared"
fi
if grep -qE 'rm -rf "\$HOME_C/hooks"' "$PACK/scripts/uninstall.sh" \
  || grep -qE 'rm -f "\$HOME_C/hooks.json"' "$PACK/scripts/uninstall.sh"; then
  fail "uninstall.sh must not wipe ~/.cursor/hooks.json or hooks/ wholesale"
else ok "uninstall.sh does not wholesale-delete hooks.json or hooks/"
fi

if [[ -z "$REF_BAD" ]]; then ok "rule/skill references resolve; optional deps are conditional"
else fail "unresolved or undeclared references:$REF_BAD"; fi

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
