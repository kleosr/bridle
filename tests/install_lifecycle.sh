#!/usr/bin/env bash
# Isolated HOME: double install idempotency, uninstall ownership, doctor fixture path.

LC_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-lc.XXXXXX")"
trap 'rm -rf "$LC_HOME"' EXIT

HOOKS_DIR="$PACK/shared/hooks"
# shellcheck source=shared/hooks/lib/fleet_install.sh
source "$HOOKS_DIR/lib/fleet_install.sh"
EXPECTED_HOOK_SH=$(( ${#HOOK_SCRIPTS[@]} + ${#RUNTIME_LIBS[@]} ))

INSTALL1_EC=0
HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || INSTALL1_EC=$?
INSTALL2_EC=0
HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || INSTALL2_EC=$?
run_test "double install first pass exits 0" "0" "$INSTALL1_EC"
run_test "double install second pass exits 0" "0" "$INSTALL2_EC"

EVT="$(HOME="$LC_HOME" jq -r '.hooks|keys|length' "$LC_HOME/.cursor/hooks.json" 2>/dev/null || echo 0)"
run_test "double install keeps 4 hook events" "4" "$EVT"

HOOK_SH_COUNT="$(find "$LC_HOME/.cursor/hooks" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
run_test "double install hook script count matches pack arrays" "$EXPECTED_HOOK_SH" "$HOOK_SH_COUNT"

DUP_BASENAMES="$(find "$LC_HOME/.cursor/hooks" -name '*.sh' -exec basename {} \; 2>/dev/null | sort | uniq -d | wc -l | tr -d ' ')"
run_test "double install has no duplicate hook script basenames" "0" "$DUP_BASENAMES"

# Unrelated artifact must survive uninstall
mkdir -p "$LC_HOME/.cursor/rules"
printf '%s\n' '---' 'alwaysApply: true' '---' '# user custom' > "$LC_HOME/.cursor/rules/my-custom.mdc"
UNINSTALL_EC=0
HOME="$LC_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || UNINSTALL_EC=$?
CUSTOM_OK="$(test -f "$LC_HOME/.cursor/rules/my-custom.mdc" && echo yes || echo no)"
HOOKS_GONE="$(test -f "$LC_HOME/.cursor/hooks.json" && echo no || echo yes)"
AGENT_GONE="$(test -f "$LC_HOME/.cursor/agents/hunter.md" && echo no || echo yes)"
PONY_GONE="$(test -f "$LC_HOME/.cursor/rules/ponytail.mdc" && echo no || echo yes)"
run_test "uninstall with FORCE unset exits 0" "0" "$UNINSTALL_EC"
run_test "uninstall removes hooks.json" "yes" "$HOOKS_GONE"
run_test "uninstall removes kleosrules agent.mdc rules" "yes" "$PONY_GONE"
run_test "uninstall removes hunter agent" "yes" "$AGENT_GONE"
run_test "uninstall preserves unrelated my-custom.mdc" "yes" "$CUSTOM_OK"

# Re-install after uninstall (migration/update path)
REINSTALL_EC=0
HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || REINSTALL_EC=$?
REINSTALL_OK="$(grep -q 'before_submit_prompt' "$LC_HOME/.cursor/hooks.json" 2>/dev/null && echo yes || echo no)"
run_test "re-install after uninstall exits 0" "0" "$REINSTALL_EC"
run_test "re-install after uninstall registers hooks" "yes" "$REINSTALL_OK"

# Directory skill copy (Windows-style) must not abort uninstall when FORCE is unset
rm -rf "$LC_HOME/.cursor/skills/debugging"
cp -r "$PACK/shared/skills/debugging" "$LC_HOME/.cursor/skills/debugging"
UNINSTALL_DIR_EC=0
HOME="$LC_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || UNINSTALL_DIR_EC=$?
DEBUGGING_REMAIN="$(test -d "$LC_HOME/.cursor/skills/debugging" && echo yes || echo no)"
UNINSTALL2_EC=0
HOME="$LC_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || UNINSTALL2_EC=$?
run_test "uninstall with directory skill and FORCE unset completes" "0" "$UNINSTALL_DIR_EC"
run_test "uninstall skips directory skill without FORCE=1" "yes" "$DEBUGGING_REMAIN"
run_test "second uninstall with FORCE unset is idempotent (skip)" "0" "$UNINSTALL2_EC"

# Legacy orphan hooks.json without scripts → heal on project-hooks path
LEG_REPO="$(mktemp -d "${TMPDIR:-/tmp}/kleos-leg.XXXXXX")"
mkdir -p "$LEG_REPO/.git" "$LEG_REPO/.cursor/hooks"
printf '{}\n' > "$LEG_REPO/.cursor/hooks.json"
heal_orphan_project_hooks "$LEG_REPO" >/dev/null 2>&1
LEG_HEALED="$(test -f "$LEG_REPO/.cursor/hooks.json" && echo no || echo yes)"
rm -rf "$LEG_REPO"
run_test "legacy orphan hooks.json healed (scripts missing)" "yes" "$LEG_HEALED"

# Doctor fixture path (no real ~/.cursor required)
DOC_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-doc.XXXXXX")"
DOC_EC=0
DOC_OUT="$(HOME="$DOC_HOME" bash "$PACK/scripts/doctor.sh" 2>&1)" || DOC_EC=$?
rm -rf "$DOC_HOME"
DOC_FIX="$(printf '%s' "$DOC_OUT" | grep -c 'fixture install: hooks.json registers beforeSubmitPrompt' || true)"
run_test "doctor reports fixture install check" "1" "$DOC_FIX"
run_test "doctor exits 0 without live ~/.cursor install" "0" "$DOC_EC"
