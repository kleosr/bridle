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

for f in "$HOOKS_DIR"/session_start.sh "$HOOKS_DIR"/before_submit_prompt.sh "$HOOKS_DIR"/before_shell.sh "$HOOKS_DIR"/before_read_file.sh "$HOOKS_DIR"/stop.sh; do
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

DOCTOR_FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/kleos-doctor.XXXXXX")"
if HOME="$DOCTOR_FIXTURE" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 \
  && grep -q 'hooks/before_submit_prompt.sh' "$DOCTOR_FIXTURE/.cursor/hooks.json" 2>/dev/null; then
  ok "fixture install: hooks.json registers beforeSubmitPrompt (isolated HOME)"
else
  fail "fixture install failed or hooks.json missing beforeSubmitPrompt"
fi
if [[ -d "$DOCTOR_FIXTURE/.cursor/hooks" ]]; then
  for rel in session_start.sh before_submit_prompt.sh before_shell.sh before_read_file.sh stop.sh lib/common.sh lib/shell_gate.sh lib/diff_gate.sh; do
    if [[ -f "$DOCTOR_FIXTURE/.cursor/hooks/$rel" ]]; then
      ok "fixture install: hooks/$rel present"
    else
      fail "fixture install: hooks/$rel missing"
    fi
  done
fi
rm -rf "$DOCTOR_FIXTURE"
if grep -q 'hooks/before_submit_prompt.sh' "${HOME}/.cursor/hooks.json" 2>/dev/null; then
  ok "live ~/.cursor has kleosrules beforeSubmitPrompt (optional — not required in CI/agent env)"
else
  echo "[info] live ~/.cursor not a kleosrules install (expected in agent/CI env; run FORCE=1 bash scripts/install.sh locally)"
fi

if jq -e '.hooks|keys|length == 5' "$HOOKS_DIR/hooks.json" >/dev/null 2>&1 \
  && jq -e '.hooks.sessionStart[0].command == "./hooks/session_start.sh"' "$HOOKS_DIR/hooks.json" >/dev/null 2>&1 \
  && jq -e '.hooks.stop[0].command == "./hooks/stop.sh" and .hooks.stop[0].loop_limit == 1' "$HOOKS_DIR/hooks.json" >/dev/null 2>&1; then
  ok "hooks.json is 5 native ./hooks/ events (stop bounded loop_limit 1)"
else fail "hooks.json must be 5 events with ./hooks/ commands and stop.loop_limit 1"; fi

if [[ -e "$PACK/.cursor/hooks.json" || -d "$PACK/.cursor/hooks" ]]; then
  fail "pack has repo-level hooks (never Lane-A into this pack)"
else ok "no repo-level hooks in pack (local global-only mode)"; fi

if ! grep -RqiE 'CallMcpTool|user-obsidian' "$HOOKS_DIR/" --include='*.sh' 2>/dev/null; then ok "no MCP core dependency in hooks"
else fail "MCP core dependency found in hooks (should be optional, not core)"; fi

if [[ -f "$PACK/NOW.md" ]] && grep -q 'COMPACTION' "$PACK/NOW.md"; then ok "NOW.md with compaction protocol"
else fail "NOW.md missing or lacks compaction protocol"; fi

if [[ -f "$PACK/SECURITY.md" ]] && grep -q 'onlyBuiltDependencies' "$PACK/SECURITY.md"; then ok "SECURITY.md present"
else fail "SECURITY.md missing or incomplete"; fi

if [[ ! -f "$PACK/HANDOFF.md" && ! -d "$PACK/shared/skills/session-handoff" ]]; then ok "HANDOFF.md and session-handoff retired"
else fail "HANDOFF.md or skills/session-handoff still on disk (use NOW.md and /now)"; fi

if [[ ! -f "$HOOKS_DIR/stop_gate.sh" && ! -f "$HOOKS_DIR/lean_gate.sh" && ! -f "$HOOKS_DIR/pre_tool_use.sh" ]]; then
  ok "unregistered event scripts removed"
else fail "unregistered event scripts still on disk"; fi

LAW_STALE=""
for f in "$PACK/shared/rules/agent.mdc" "$PACK/shared/rules/ponytail.mdc" \
  "$PACK/shared/rules/vibe.mdc" "$PACK/shared/rules/postgres.mdc" \
  "$PACK/shared/rules/next.mdc" "$PACK/shared/rules/vite.mdc" \
  "$PACK/shared/rules/astro.mdc" "$PACK/shared/rules/complexity.mdc" \
  "$PACK/shared/rules/pnpm.mdc" \
  "$PACK/shared/rules/USER-RULES.paste.txt" "$PACK/shared/skills/ponytail/SKILL.md" \
  "$PACK/shared/skills/testing/SKILL.md" \
  "$PACK/shared/skills/complexity/SKILL.md"; do
  [[ -f "$f" ]] || { LAW_STALE="$LAW_STALE missing:${f#$PACK/}"; continue; }
  if grep -qE 'stop_gate|lean_gate|post_tool_use|pre_tool_use|before_mcp' "$f"; then
    LAW_STALE="$LAW_STALE ${f#$PACK/}"
  fi
done
if [[ -z "$LAW_STALE" ]]; then ok "law/skills match five-hook harness (no deleted 2026-08 gate names)"
else fail "stale deleted-hook names in$LAW_STALE"; fi

if [[ ! -f "$PACK/shared/rules/native-lean-autoload.mdc" && ! -f "$PACK/shared/rules/debugging.mdc" ]]; then ok "merged/retired duplicate mdc gone"
else fail "native-lean-autoload.mdc or debugging.mdc still on disk"; fi

if grep -q 'hard 300' "$PACK/shared/rules/ponytail.mdc"; then ok "ponytail.mdc has hard 300 roof"
else fail "ponytail.mdc missing hard 300 roof"; fi

if [[ ! -f "$PACK/shared/rules/vernacular.mdc" && ! -d "$PACK/shared/skills/vernacular" ]]; then ok "vernacular retired"
else fail "vernacular.mdc or skills/vernacular still on disk"; fi

if [[ ! -f "$PACK/shared/rules/mario-engineering-team.mdc" ]]; then ok "mario-engineering-team retired"
else fail "mario-engineering-team.mdc still on disk"; fi

if [[ -f "$PACK/shared/rules/pnpm.mdc" && -f "$PACK/shared/agents/hunter.md" ]]; then ok "pnpm.mdc + hunter/cut/prove in pack"
else fail "pnpm.mdc or shared/agents/hunter.md missing"; fi

if [[ ! -f "$PACK/shared/rules/lean-code.mdc" && ! -d "$PACK/shared/skills/lean-code" ]]; then ok "no lean-code duplicate"
else fail "Duplicate found: lean-code (use ponytail instead)"; fi

if ! grep -RqE '(lean-code|codebase-memory|architecture-fitness|domain-architecture|improve-codebase-architecture|eval-pass|unconditional-counterexample|create-pr|git-commit|ship-loop|cursor-research|grill-me|harness-retro|design-taste-frontend|design-tokens|frontend-design|ui-structure|ui-ux-audit|formulary|no-hardcode|humanizer|system-wiring|workspace-scope|agents-map|benln-write|breakthrough-deepen)' "$HOOKS_DIR/fleet_sync.sh" "$PACK/shared/config/skills.txt" "$PACK/shared/skills/AGENTS.md" "$PACK/shared/rules/AGENTS.md" "$PACK/README.md" 2>/dev/null; then ok "no stale references to deleted skills"
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
if grep -q 'hooks/before_submit_prompt.sh' "${HOME}/.cursor/hooks.json" 2>/dev/null && [[ -d "$HOME_HOOKS" ]]; then
  if hash_file "$HOOKS_DIR/session_start.sh" >/dev/null; then
    for rel in session_start.sh before_submit_prompt.sh before_shell.sh before_read_file.sh stop.sh lib/common.sh lib/shell_gate.sh lib/diff_gate.sh; do
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

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "=== ALL CHECKS PASSED ==="
  exit 0
else
  echo "=== SOME CHECKS FAILED ==="
  exit 1
fi
