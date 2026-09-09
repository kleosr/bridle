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

EVT="$(jq -r '.hooks | [has("beforeSubmitPrompt"),has("beforeShellExecution"),has("beforeReadFile"),has("stop")] | map(select(.)) | length' "$LC_HOME/.cursor/hooks.json" 2>/dev/null || echo 0)"
run_test "double install registers the 4 required events" "4" "$EVT"

TYPES_HOME="$(test -f "$LC_HOME/.cursor/rules/types.mdc" && echo yes || echo no)"
run_test "install copies types.mdc into isolated HOME rules" "yes" "$TYPES_HOME"
HUNTER_HOME="$(test -f "$LC_HOME/.cursor/agents/hunter.md" && echo yes || echo no)"
CUT_HOME="$(test -f "$LC_HOME/.cursor/agents/cut.md" && echo yes || echo no)"
PROVE_HOME="$(test -f "$LC_HOME/.cursor/agents/prove.md" && echo yes || echo no)"
run_test "install copies hunter/cut/prove agents" "yes" "$([[ "$HUNTER_HOME$CUT_HOME$PROVE_HOME" == yesyesyes ]] && echo yes || echo no)"
PONY_SKILL="$(test -e "$LC_HOME/.cursor/skills/ponytail/SKILL.md" && echo yes || echo no)"
PREM_SRC="$(test -e "$LC_HOME/.cursor/skills/premium-ui-craft/SOURCE.md" && echo yes || echo no)"
PREM_OLD="$(test -e "$LC_HOME/.cursor/skills/premium-ui-craft/sources.md" && echo yes || echo no)"
run_test "install links ponytail skill" "yes" "$PONY_SKILL"
run_test "install links premium-ui-craft SOURCE.md" "yes" "$PREM_SRC"
run_test "install does not leave sources.md" "no" "$PREM_OLD"
PACK_TYPES_LC="$(test -e "$PACK/.cursor/rules/types.mdc" && echo yes || echo no)"
run_test "install prunes types.mdc from pack project rules" "no" "$PACK_TYPES_LC"

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
TYPES_GONE="$(test -f "$LC_HOME/.cursor/rules/types.mdc" && echo no || echo yes)"
run_test "uninstall with FORCE unset exits 0" "0" "$UNINSTALL_EC"
run_test "uninstall removes hooks.json when only pack events remain" "yes" "$HOOKS_GONE"
run_test "uninstall removes kleosrules agent.mdc rules" "yes" "$PONY_GONE"
run_test "uninstall removes types.mdc" "yes" "$TYPES_GONE"
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

WIN_U_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-winu.XXXXXX")"
mkdir -p "$WIN_U_HOME/.cursor/hooks"
printf '%s\n' '{"hooks":{"beforeSubmitPrompt":[{"command":"powershell -File C:\\Users\\x\\.cursor\\hooks\\bash-shim.ps1 before_submit_prompt.sh"}]}}' > "$WIN_U_HOME/.cursor/hooks.json"
WIN_U_EC=0
HOME="$WIN_U_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || WIN_U_EC=$?
WIN_U_GONE="$(test -f "$WIN_U_HOME/.cursor/hooks.json" && echo no || echo yes)"
rm -rf "$WIN_U_HOME"
run_test "uninstall recognizes Windows bash-shim hooks.json" "0" "$WIN_U_EC"
run_test "uninstall removes Windows bash-shim hooks.json when only pack entries remain" "yes" "$WIN_U_GONE"

MIX_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-mix.XXXXXX")"
mkdir -p "$MIX_HOME/.cursor/hooks"
printf '%s\n' '{"version":1,"extra":true,"hooks":{"beforeSubmitPrompt":[{"command":"./hooks/user_audit.sh","failClosed":false},{"command":"./hooks/before_submit_prompt.sh"}],"stop":[{"command":"./hooks/stop.sh"}]}}' > "$MIX_HOME/.cursor/hooks.json"
printf '%s\n' '#!/bin/sh' 'echo ok' > "$MIX_HOME/.cursor/hooks/user_audit.sh"
printf '%s\n' '#!/bin/sh' 'echo pack' > "$MIX_HOME/.cursor/hooks/before_submit_prompt.sh"
printf '%s\n' '#!/bin/sh' 'echo pack' > "$MIX_HOME/.cursor/hooks/stop.sh"
MIX_EC=0
HOME="$MIX_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || MIX_EC=$?
MIX_KEEP="$(jq -r '.hooks.beforeSubmitPrompt[0].command' "$MIX_HOME/.cursor/hooks.json" 2>/dev/null || echo missing)"
MIX_EXTRA="$(jq -r '.extra' "$MIX_HOME/.cursor/hooks.json" 2>/dev/null || echo missing)"
MIX_STOP="$(jq -r '.hooks|has("stop")' "$MIX_HOME/.cursor/hooks.json" 2>/dev/null || echo missing)"
MIX_USER="$(test -f "$MIX_HOME/.cursor/hooks/user_audit.sh" && echo yes || echo no)"
MIX_PACK="$(test -f "$MIX_HOME/.cursor/hooks/before_submit_prompt.sh" && echo yes || echo no)"
rm -rf "$MIX_HOME"
run_test "uninstall with mixed hooks.json exits 0" "0" "$MIX_EC"
run_test "uninstall preserves unrelated hook command" "./hooks/user_audit.sh" "$MIX_KEEP"
run_test "uninstall preserves unknown hooks.json keys" "true" "$MIX_EXTRA"
run_test "uninstall drops owned stop event when no user entries remain" "false" "$MIX_STOP"
run_test "uninstall keeps unrelated hook script file" "yes" "$MIX_USER"
run_test "uninstall removes owned before_submit_prompt.sh" "no" "$MIX_PACK"

FP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-fp.XXXXXX")"
mkdir -p "$FP_HOME/.cursor/hooks"
printf '%s\n' '{"hooks":{"beforeSubmitPrompt":[{"command":"powershell -File C:\\Users\\x\\.cursor\\hooks\\bash-shim.ps1 my_custom.sh"}]}}' > "$FP_HOME/.cursor/hooks.json"
printf '%s\n' 'echo shim' > "$FP_HOME/.cursor/hooks/bash-shim.ps1"
FP_EC=0
HOME="$FP_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || FP_EC=$?
FP_KEEP="$(test -f "$FP_HOME/.cursor/hooks.json" && echo yes || echo no)"
FP_CMD="$(jq -r '.hooks.beforeSubmitPrompt[0].command' "$FP_HOME/.cursor/hooks.json" 2>/dev/null || echo missing)"
FP_SHIM="$(test -f "$FP_HOME/.cursor/hooks/bash-shim.ps1" && echo yes || echo no)"
rm -rf "$FP_HOME"
run_test "uninstall does not treat bare bash-shim as pack ownership" "0" "$FP_EC"
run_test "uninstall preserves user bash-shim hooks.json" "yes" "$FP_KEEP"
run_test "uninstall preserves user bash-shim command" "yes" "$(printf '%s' "$FP_CMD" | grep -q 'my_custom.sh' && echo yes || echo no)"
run_test "uninstall keeps shim when remaining commands reference it" "yes" "$FP_SHIM"

MERGE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-merge.XXXXXX")"
mkdir -p "$MERGE_HOME/.cursor"
printf '%s\n' '{"version":1,"hooks":{"beforeShellExecution":[{"command":"./hooks/user_audit.sh"}]}}' > "$MERGE_HOME/.cursor/hooks.json"
HOME="$MERGE_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1
MERGE_USER="$(jq -r '.hooks.beforeShellExecution | map(.command) | map(select(test("user_audit"))) | length' "$MERGE_HOME/.cursor/hooks.json" 2>/dev/null || echo 0)"
MERGE_PACK="$(jq -r '.hooks.beforeShellExecution | map(.command) | map(select(test("before_shell"))) | length' "$MERGE_HOME/.cursor/hooks.json" 2>/dev/null || echo 0)"
MERGE_EVT="$(jq -r '.hooks | [has("beforeSubmitPrompt"),has("beforeShellExecution"),has("beforeReadFile"),has("stop")] | map(select(.)) | length' "$MERGE_HOME/.cursor/hooks.json" 2>/dev/null || echo 0)"
rm -rf "$MERGE_HOME"
run_test "install merge keeps pre-existing user hook entry" "1" "$MERGE_USER"
run_test "install merge adds pack before_shell entry" "1" "$MERGE_PACK"
run_test "install merge registers all 4 required events" "4" "$MERGE_EVT"

# Legacy orphan hooks.json without scripts → heal on project-hooks path
LEG_REPO="$(mktemp -d "${TMPDIR:-/tmp}/kleos-leg.XXXXXX")"
mkdir -p "$LEG_REPO/.git" "$LEG_REPO/.cursor/hooks"
printf '{}\n' > "$LEG_REPO/.cursor/hooks.json"
heal_orphan_project_hooks "$LEG_REPO" >/dev/null 2>&1
LEG_HEALED="$(test -f "$LEG_REPO/.cursor/hooks.json" && echo no || echo yes)"
rm -rf "$LEG_REPO"
run_test "legacy orphan hooks.json healed (scripts missing)" "yes" "$LEG_HEALED"

OWN_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-own.XXXXXX")"
mkdir -p "$OWN_HOME/.cursor/rules"
printf '%s\n' '# user agent' > "$OWN_HOME/.cursor/rules/agent.mdc"
HOME="$OWN_HOME" FORCE=0 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || true
OWN_SKIP="$(grep -q 'user agent' "$OWN_HOME/.cursor/rules/agent.mdc" 2>/dev/null && echo kept || echo replaced)"
HOME="$OWN_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || true
OWN_BAK="$(test -f "$OWN_HOME/.cursor/rules/agent.mdc.pre-kleos-bak" && echo yes || echo no)"
HOME="$OWN_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || true
OWN_RESTORE="$(grep -q 'user agent' "$OWN_HOME/.cursor/rules/agent.mdc" 2>/dev/null && echo yes || echo no)"
rm -rf "$OWN_HOME"
run_test "install without FORCE keeps differing user rule" "kept" "$OWN_SKIP"
run_test "install with FORCE backs up differing user rule" "yes" "$OWN_BAK"
run_test "uninstall restores user rule backup" "yes" "$OWN_RESTORE"

RET_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-ret.XXXXXX")"
mkdir -p "$RET_HOME/.cursor/skills" "$RET_HOME/other/now" "$RET_HOME/kleosrules/shared/skills/now"
printf '%s\n' '# user now skill' > "$RET_HOME/other/now/SKILL.md"
printf '%s\n' '# retired pack now skill' > "$RET_HOME/kleosrules/shared/skills/now/SKILL.md"
ln -s "$RET_HOME/kleosrules/shared/skills/now" "$RET_HOME/.cursor/skills/now"
ln -s "$RET_HOME/other/now" "$RET_HOME/.cursor/skills/memory"
if [[ -L "$RET_HOME/.cursor/skills/now" ]]; then HAVE_LINK=yes; else HAVE_LINK=no; fi
HOME="$RET_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || true
RET_OWNED="$(if [[ -e "$RET_HOME/.cursor/skills/now" || -L "$RET_HOME/.cursor/skills/now" ]]; then echo yes; else echo no; fi)"
RET_FOREIGN="$(if [[ -e "$RET_HOME/.cursor/skills/memory" || -L "$RET_HOME/.cursor/skills/memory" ]]; then echo yes; else echo no; fi)"
rm -rf "$RET_HOME"
if [[ "$HAVE_LINK" == "yes" ]]; then
  run_test "upgrade prunes pack-owned retired skill symlink" "no" "$RET_OWNED"
else
  run_test "upgrade keeps retired skill dir-copy (no symlink ownership to verify)" "yes" "$RET_OWNED"
fi
run_test "upgrade keeps foreign skill under a retired skill name" "yes" "$RET_FOREIGN"

# Doctor fixture path (no real ~/.cursor required)
DOC_ISO="$(mktemp -d "${TMPDIR:-/tmp}/kleos-dociso.XXXXXX")"
if HOME="$DOC_ISO" bash "$PACK/scripts/doctor.sh" >"$DOC_ISO/out.txt" 2>&1; then DOC_EC=0; else DOC_EC=$?; fi
DOC_OUT="$(cat "$DOC_ISO/out.txt")"
rm -rf "$DOC_ISO"
DOC_FIX="$(printf '%s' "$DOC_OUT" | grep -c 'fixture install: hooks.json registers beforeSubmitPrompt' || true)"
run_test "doctor reports fixture install check" "1" "$DOC_FIX"
run_test "doctor exits 0 with isolated HOME" "0" "$DOC_EC"
