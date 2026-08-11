#!/usr/bin/env bash
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$PACK/shared/hooks"
FAIL=0

ok() { echo "[ok] $1"; }
fail() { echo "[fail] $1"; FAIL=1; }

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

if jq -e '.complexity_max and .func_complexity_max and .coupling_max and .nesting_max' "$HOOKS_DIR/policy/lean.json" >/dev/null 2>&1; then ok "lean.json has complexity/coupling/nesting thresholds"
else fail "lean.json missing new metric thresholds"; fi

if [[ -f "$HOOKS_DIR/lib/metrics.sh" ]] && grep -q 'metrics.sh' "$HOOKS_DIR/lean_gate.sh"; then ok "metrics.sh wired into lean_gate"
else fail "metrics.sh missing or not sourced by lean_gate"; fi

POLICY_COUNT="$(find "$HOOKS_DIR/policy" -name '*.json' 2>/dev/null | wc -l)"
if [[ "$POLICY_COUNT" -eq 2 ]]; then ok "policy count = 2 (intent + lean only)"
else fail "policy count = $POLICY_COUNT (expected 2)"; fi

for p in "$HOOKS_DIR"/policy/*.json; do
  [[ -f "$p" ]] || continue
  if jq empty "$p" 2>/dev/null; then ok "policy valid: ${p#$PACK/}"
  else fail "policy invalid JSON: ${p#$PACK/}"; fi
done

if [[ ! -e "$HOOKS_DIR/kleos-gate" && ! -e "$HOOKS_DIR/bin/kleos-gate" ]]; then ok "no Rust kleos-gate"
else fail "Rust kleos-gate detected — should be removed"; fi

if ! grep -Rq --include='*.sh' 'updated_input' "$HOOKS_DIR/" 2>/dev/null; then ok "no updated_input in hooks"
else fail "updated_input found in hooks (banned)"; fi

# lib/common.sh is the sanctioned platform shim (guarded stat branch); comments exempt.
GNU_HITS="$(grep -Rn --include='*.sh' -E 'flock|mapfile|readlink -f|stat -c' "$HOOKS_DIR/" 2>/dev/null \
  | grep -vE ':[0-9]+:[[:space:]]*#' | grep -v 'lib/common\.sh' || true)"
if [[ -z "$GNU_HITS" ]]; then ok "no GNU-only utils in hooks (macOS safe)"
else fail "GNU-only util found in hooks: $GNU_HITS"; fi

for f in "$HOOKS_DIR"/session_start.sh "$HOOKS_DIR"/before_submit_prompt.sh "$HOOKS_DIR"/stop_gate.sh "$HOOKS_DIR"/lean_gate.sh "$HOOKS_DIR"/pre_tool_use.sh; do
  n="$(wc -l < "$f")"
  if [[ "$n" -le 80 ]]; then ok "LOC ≤ 80: ${f#$PACK/} ($n)"
  else fail "LOC > 80: ${f#$PACK/} ($n)"; fi
done

for d in shared/hooks shared/hooks/lib shared/hooks/policy shared/rules shared/skills shared/config MacOS Linux Windows docs scripts tests; do
  if [[ -d "$PACK/$d" ]]; then ok "dir exists: $d/"
  else fail "missing dir: $d/"; fi
done

while IFS= read -r cmd; do
  [[ -z "$cmd" ]] && continue
  script="${cmd#./hooks/}"
  script="${script%% *}"
  if [[ -f "$HOOKS_DIR/$script" ]]; then ok "hook ref exists: $script"
  else fail "hook ref missing: $script (from hooks.json)"; fi
done < <(jq -r '.hooks | to_entries[] | .value[]? | .command // empty' "$HOOKS_DIR/hooks.json" 2>/dev/null || true)

if grep -q '^state/' "$PACK/.gitignore" && grep -q '\.cursor/' "$PACK/.gitignore"; then ok ".gitignore covers state/ and .cursor/"
else fail ".gitignore missing state/ or .cursor/ coverage"; fi

if grep -q 'hooks/before_submit_prompt.sh' "$HOME/.cursor/hooks.json" 2>/dev/null; then
  ok "global hook registration (~/.cursor single layer)"
else fail "~/.cursor/hooks.json missing beforeSubmitPrompt (run: bash shared/hooks/fleet_sync.sh install)"; fi

if [[ -f "$PACK/.cursor/hooks.json" ]] && jq -e '.hooks.sessionStart' "$PACK/.cursor/hooks.json" >/dev/null 2>&1; then
  fail "pack project hooks register sessionStart — double DUTY (use hooks.cloud.json / project-hooks)"
elif [[ -e "$PACK/.cursor/hooks.json" || -d "$PACK/.cursor/hooks" ]]; then
  if jq -e '.hooks.preToolUse' "$PACK/.cursor/hooks.json" >/dev/null 2>&1; then
    ok "pack has thin Lane-A project hooks (no sessionStart; cloud-safe)"
  else
    fail "pack has unexpected repo-level hooks"
  fi
else ok "no repo-level hooks in pack (local global-only mode)"; fi

if ! grep -RqiE 'CallMcpTool|user-obsidian' "$HOOKS_DIR/" --include='*.sh' 2>/dev/null; then ok "no MCP core dependency in hooks"
else fail "MCP core dependency found in hooks (should be optional, not core)"; fi

if [[ -f "$PACK/HANDOFF.md" ]] && grep -q 'COMPACTION' "$PACK/HANDOFF.md"; then ok "HANDOFF.md with compaction protocol"
else fail "HANDOFF.md missing or lacks compaction protocol"; fi

for wrapper in stop_gate pre_tool_use; do
  if grep -q 'source.*lib/.*_core.sh' "$HOOKS_DIR/${wrapper}.sh" 2>/dev/null; then ok "wrapper sources lib: ${wrapper}.sh"
  else fail "wrapper missing source: ${wrapper}.sh"; fi
done

if [[ ! -f "$PACK/shared/rules/lean-code.mdc" && ! -d "$PACK/shared/skills/lean-code" ]]; then ok "no lean-code duplicate"
else fail "Duplicate found: lean-code (use ponytail instead)"; fi

if ! grep -RqE '(lean-code|codebase-memory|architecture-fitness|domain-architecture|improve-codebase-architecture|eval-pass|unconditional-counterexample|create-pr|git-commit|ship-loop|cursor-research|grill-me|harness-retro|design-taste-frontend|design-tokens|frontend-design|ui-structure|ui-ux-audit|formulary|no-hardcode|humanizer|system-wiring|workspace-scope|agents-map|benln-write|breakthrough-deepen)' "$HOOKS_DIR/fleet_sync.sh" "$PACK/shared/config/skills.txt" "$PACK/shared/skills/AGENTS.md" "$PACK/shared/rules/AGENTS.md" "$PACK/README.md" 2>/dev/null; then ok "no stale references to deleted skills"
else fail "Stale reference to deleted skill found in config files"; fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "=== ALL CHECKS PASSED ==="
  exit 0
else
  echo "=== SOME CHECKS FAILED ==="
  exit 1
fi
