#!/usr/bin/env bash
# scripts/doctor.sh — environment + repository health check.
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

ok() { echo "[ok] $1"; }
fail() { echo "[fail] $1"; FAIL=1; }

# 1. Bash version ≥ 4
if [[ "${BASH_VERSINFO[0]:-0}" -ge 4 ]]; then ok "bash >= 4 (${BASH_VERSION})"
else fail "bash >= 4 required (found ${BASH_VERSION:-unknown})"; fi

# 2. jq presence
if command -v jq >/dev/null 2>&1; then ok "jq $(jq --version 2>/dev/null || echo 'present')"
else fail "jq not found — required for JSON parsing in hooks"; fi

# 3. shellcheck (optional but recommended)
if command -v shellcheck >/dev/null 2>&1; then ok "shellcheck available"
else echo "[warn] shellcheck not found (optional, recommended for CI)"; fi

# 4. Hook scripts executable
for f in "$PACK"/hooks/*.sh "$PACK"/hooks/lib/*.sh; do
  [[ -f "$f" ]] || continue
  if [[ -x "$f" ]]; then ok "executable: ${f#$PACK/}"
  else fail "not executable: ${f#$PACK/}"; fi
done

# 5. Hook config valid JSON
if jq empty "$PACK/hooks/hooks.json" 2>/dev/null; then ok "hooks/hooks.json valid JSON"
else fail "hooks/hooks.json invalid JSON"; fi

# 6. Policy files valid JSON
for p in "$PACK"/hooks/policy/*.json; do
  [[ -f "$p" ]] || continue
  if jq empty "$p" 2>/dev/null; then ok "policy valid: ${p#$PACK/}"
  else fail "policy invalid JSON: ${p#$PACK/}"; fi
done

# 7. Wired policy count = 2 (intent + lean only)
POLICY_COUNT="$(find "$PACK/hooks/policy" -name '*.json' 2>/dev/null | wc -l)"
POLICY_COUNT="${POLICY_COUNT//[!0-9]}"
if [[ "$POLICY_COUNT" -eq 2 ]]; then ok "policy count = 2 (intent + lean only)"
else fail "expected 2 policy files, found $POLICY_COUNT"; fi

# 8. No Rust gate remnants
if [[ ! -e "$PACK/hooks/kleos-gate" && ! -e "$PACK/hooks/bin/kleos-gate" ]]; then ok "no Rust kleos-gate"
else fail "Rust kleos-gate detected — should be removed"; fi

# 9. No updated_input in hooks
if ! grep -Rq --include='*.sh' 'updated_input' "$PACK/hooks/" 2>/dev/null; then ok "no updated_input in hooks"
else fail "updated_input found in hooks (banned)"; fi

# 10. Event hook LOC ≤ 80
for f in "$PACK"/hooks/session_start.sh "$PACK"/hooks/before_submit_prompt.sh "$PACK"/hooks/stop_gate.sh "$PACK"/hooks/lean_gate.sh "$PACK"/hooks/pre_tool_use.sh; do
  n="$(wc -l < "$f")"
  if [[ "$n" -le 80 ]]; then ok "LOC ≤ 80: ${f#$PACK/} ($n)"
  else fail "LOC > 80: ${f#$PACK/} ($n)"; fi
done

# 11. Required directories exist
for d in hooks hooks/lib hooks/policy project-rules user-rules skills config docs scripts tests; do
  if [[ -d "$PACK/$d" ]]; then ok "dir exists: $d/"
  else fail "missing dir: $d/"; fi
done

# 12. Hook config references existing files
while IFS= read -r cmd; do
  [[ -z "$cmd" ]] && continue
  script="${cmd#./hooks/}"
  script="${script%% *}"
  if [[ -f "$PACK/hooks/$script" ]]; then ok "hook ref exists: $script"
  else fail "hook ref missing: $script (from hooks.json)"; fi
done < <(jq -r '.hooks | to_entries[] | .value[]? | .command // empty' "$PACK/hooks/hooks.json" 2>/dev/null || true)

# 13. .gitignore covers local state
if grep -q '^state/' "$PACK/.gitignore" && grep -q '\.cursor/' "$PACK/.gitignore"; then ok ".gitignore covers state/ and .cursor/"
else fail ".gitignore missing state/ or .cursor/ coverage"; fi

# 14. No MCP core dependency in hooks (optional mentions are fine)
if ! grep -RqiE 'CallMcpTool|user-obsidian' "$PACK/hooks/" --include='*.sh' 2>/dev/null; then ok "no MCP core dependency in hooks"
else fail "MCP core dependency found in hooks (should be optional, not core)"; fi

# 15. HANDOFF.md exists with compaction protocol
if [[ -f "$PACK/HANDOFF.md" ]] && grep -q 'COMPACTION' "$PACK/HANDOFF.md"; then ok "HANDOFF.md with compaction protocol"
else fail "HANDOFF.md missing or lacks compaction protocol"; fi

# 16. lib/ scripts sourced correctly by wrappers
for wrapper in stop_gate pre_tool_use; do
  if grep -q 'source.*lib/.*_core.sh' "$PACK/hooks/${wrapper}.sh" 2>/dev/null; then ok "wrapper sources lib: ${wrapper}.sh"
  else fail "wrapper missing source: ${wrapper}.sh"; fi
done

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "=== ALL CHECKS PASSED ==="
  exit 0
else
  echo "=== SOME CHECKS FAILED ==="
  exit 1
fi
