#!/usr/bin/env bash
# Isolated HOME: double install idempotency, uninstall ownership, doctor fixture path.

LC_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-lc.XXXXXX")"
trap 'rm -rf "$LC_HOME"' EXIT

install_once() {
  HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1
}

if install_once && install_once; then
  EVT="$(HOME="$LC_HOME" jq -r '.hooks|keys|length' "$LC_HOME/.cursor/hooks.json" 2>/dev/null || echo 0)"
  DUP_HOOKS="$(find "$LC_HOME/.cursor/hooks" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
  run_test "double install succeeds (idempotent)" "0" "0"
  run_test "double install keeps 4 hook events" "4" "$EVT"
  run_test "double install does not duplicate hook scripts" "7" "$DUP_HOOKS"
else
  run_test "double install succeeds (idempotent)" "0" "1"
fi

# Unrelated artifact must survive uninstall
mkdir -p "$LC_HOME/.cursor/rules"
printf '%s\n' '---' 'alwaysApply: true' '---' '# user custom' > "$LC_HOME/.cursor/rules/my-custom.mdc"
HOME="$LC_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1
CUSTOM_OK="$(test -f "$LC_HOME/.cursor/rules/my-custom.mdc" && echo yes || echo no)"
HOOKS_GONE="$(test -f "$LC_HOME/.cursor/hooks.json" && echo no || echo yes)"
AGENT_GONE="$(test -f "$LC_HOME/.cursor/agents/hunter.md" && echo no || echo yes)"
PONY_GONE="$(test -f "$LC_HOME/.cursor/rules/ponytail.mdc" && echo no || echo yes)"
run_test "uninstall removes hooks.json" "yes" "$HOOKS_GONE"
run_test "uninstall removes kleosrules agent.mdc rules" "yes" "$PONY_GONE"
run_test "uninstall removes hunter agent" "yes" "$AGENT_GONE"
run_test "uninstall preserves unrelated my-custom.mdc" "yes" "$CUSTOM_OK"

# Re-install after uninstall (migration/update path)
if HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 \
  && grep -q 'before_submit_prompt' "$LC_HOME/.cursor/hooks.json" 2>/dev/null; then
  run_test "re-install after uninstall succeeds" "yes" "yes"
else
  run_test "re-install after uninstall succeeds" "yes" "no"
fi

# Legacy orphan hooks.json without scripts → heal on project-hooks path
LEG_REPO="$(mktemp -d "${TMPDIR:-/tmp}/kleos-leg.XXXXXX")"
mkdir -p "$LEG_REPO/.git" "$LEG_REPO/.cursor/hooks"
printf '{}\n' > "$LEG_REPO/.cursor/hooks.json"
source "$PACK/shared/hooks/lib/fleet_install.sh"
heal_orphan_project_hooks "$LEG_REPO" >/dev/null 2>&1
LEG_HEALED="$(test -f "$LEG_REPO/.cursor/hooks.json" && echo no || echo yes)"
rm -rf "$LEG_REPO"
run_test "legacy orphan hooks.json healed (scripts missing)" "yes" "$LEG_HEALED"

# Doctor fixture path (no real ~/.cursor required)
DOC_OUT="$(bash "$PACK/scripts/doctor.sh" 2>&1)"
DOC_EC=$?
DOC_FIX="$(printf '%s' "$DOC_OUT" | grep -c 'fixture install: hooks.json registers beforeSubmitPrompt' || true)"
run_test "doctor reports fixture install check" "1" "$DOC_FIX"
run_test "doctor exits 0 without live ~/.cursor install" "0" "$DOC_EC"
