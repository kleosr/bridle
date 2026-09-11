#!/usr/bin/env bash
# Sourced by run.sh. Isolated HOME: double-install idempotency, uninstall
# ownership, merge preservation, doctor fixture path.

LC_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-lc.XXXXXX")"
# No EXIT trap here: this file is sourced by run.sh and must not replace its
# cleanup trap. LC_HOME is removed at the end of this file.

HOOKS_DIR="$PACK/shared/hooks"
# shellcheck source=shared/hooks/lib/fleet_install.sh
source "$HOOKS_DIR/lib/fleet_install.sh"
EXPECTED_HOOK_SH=$((4 + 4))

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
run_test "install links ponytail skill" "yes" "$PONY_SKILL"
SHELL_FLEET="$(test -e "$LC_HOME/.cursor/hooks/lib/shell_fleet.sh" && echo yes || echo no)"
run_test "install does not ship v1 shell_fleet.sh" "no" "$SHELL_FLEET"

HOOK_SH_COUNT="$(find "$LC_HOME/.cursor/hooks" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
run_test "double install hook script count matches (4 scripts + 4 libs)" "$EXPECTED_HOOK_SH" "$HOOK_SH_COUNT"

DUP_BASENAMES="$(find "$LC_HOME/.cursor/hooks" -name '*.sh' -exec basename {} \; 2>/dev/null | sort | uniq -d | wc -l | tr -d ' ')"
run_test "double install has no duplicate hook script basenames" "0" "$DUP_BASENAMES"

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

REINSTALL_EC=0
HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || REINSTALL_EC=$?
REINSTALL_OK="$(grep -q 'before_submit_prompt' "$LC_HOME/.cursor/hooks.json" 2>/dev/null && echo yes || echo no)"
run_test "re-install after uninstall exits 0" "0" "$REINSTALL_EC"
run_test "re-install after uninstall registers hooks" "yes" "$REINSTALL_OK"

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

# Uninstall must preserve a user hook whose name collides with a pack substring.
COLL_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-coll.XXXXXX")"
mkdir -p "$COLL_HOME/.cursor/hooks"
printf '%s\n' '{"version":1,"hooks":{"stop":[{"command":"/home/u/hooks/my_stop.sh"},{"command":"./hooks/stop.sh"}]}}' > "$COLL_HOME/.cursor/hooks.json"
printf '%s\n' '#!/bin/sh' 'echo pack' > "$COLL_HOME/.cursor/hooks/stop.sh"
printf '%s\n' '#!/bin/sh' 'echo user' > "$COLL_HOME/.cursor/hooks/my_stop.sh"
COLL_EC=0
HOME="$COLL_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || COLL_EC=$?
COLL_KEEP="$(jq -r '[.hooks.stop[]?.command] | map(select(test("my_stop"))) | length' "$COLL_HOME/.cursor/hooks.json" 2>/dev/null || echo missing)"
COLL_USER="$(test -f "$COLL_HOME/.cursor/hooks/my_stop.sh" && echo yes || echo no)"
COLL_PACK="$(test -f "$COLL_HOME/.cursor/hooks/stop.sh" && echo yes || echo no)"
rm -rf "$COLL_HOME"
run_test "uninstall with colliding user hook exits 0" "0" "$COLL_EC"
run_test "uninstall preserves user my_stop.sh entry" "1" "$COLL_KEEP"
run_test "uninstall keeps user my_stop.sh file" "yes" "$COLL_USER"
run_test "uninstall removes owned stop.sh file" "no" "$COLL_PACK"

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

DOC_ISO="$(mktemp -d "${TMPDIR:-/tmp}/kleos-dociso.XXXXXX")"
if HOME="$DOC_ISO" bash "$PACK/scripts/doctor.sh" >"$DOC_ISO/out.txt" 2>&1; then DOC_EC=0; else DOC_EC=$?; fi
DOC_OUT="$(cat "$DOC_ISO/out.txt")"
rm -rf "$DOC_ISO"
DOC_FIX="$(printf '%s' "$DOC_OUT" | grep -c 'fixture install: hooks.json registers beforeSubmitPrompt' || true)"
run_test "doctor reports fixture install check" "1" "$DOC_FIX"
run_test "doctor exits 0 with isolated HOME" "0" "$DOC_EC"

DOC_SKIP="$(mktemp -d "${TMPDIR:-/tmp}/kleos-docskip.XXXXXX")"
if HOME="$DOC_SKIP" DOCTOR_SKIP_LIVE=1 bash "$PACK/scripts/doctor.sh" >"$DOC_SKIP/out.txt" 2>&1; then DOC_SKIP_EC=0; else DOC_SKIP_EC=$?; fi
DOC_SKIP_OUT="$(cat "$DOC_SKIP/out.txt")"
rm -rf "$DOC_SKIP"
if printf '%s' "$DOC_SKIP_OUT" | grep -q 'live ~/.cursor was not verified'; then DOC_SKIP_MSG=yes; else DOC_SKIP_MSG=no; fi
if printf '%s' "$DOC_SKIP_OUT" | grep -q 'CHECKOUT CHECKS PASSED'; then DOC_SKIP_CO=yes; else DOC_SKIP_CO=no; fi
if printf '%s' "$DOC_SKIP_OUT" | grep -q 'ALL CHECKS PASSED'; then DOC_SKIP_ALL=yes; else DOC_SKIP_ALL=no; fi
run_test "DOCTOR_SKIP_LIVE=1 exits 0" "0" "$DOC_SKIP_EC"
run_test "DOCTOR_SKIP_LIVE=1 states live was not verified" "yes" "$DOC_SKIP_MSG"
run_test "DOCTOR_SKIP_LIVE=1 uses checkout banner" "yes" "$DOC_SKIP_CO"
run_test "DOCTOR_SKIP_LIVE=1 does not claim ALL CHECKS PASSED" "no" "$DOC_SKIP_ALL"

DRY_H="$(mktemp -d "${TMPDIR:-/tmp}/kleos-dry.XXXXXX")"
DRY_EC=0
HOME="$DRY_H" DRY_RUN=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || DRY_EC=$?
DRY_HOOKS="$(test -e "$DRY_H/.cursor" && echo yes || echo no)"
rm -rf "$DRY_H"
run_test "dry-run install exits 0" "0" "$DRY_EC"
run_test "dry-run install writes no .cursor" "no" "$DRY_HOOKS"

rm -rf "$LC_HOME"
