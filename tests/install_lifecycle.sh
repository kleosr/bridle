#!/usr/bin/env bash
# Sourced by run.sh. Isolated HOME: double-install idempotency, uninstall
# ownership, merge preservation, doctor fixture path.

LC_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-lc.XXXXXX")"
# No EXIT trap here: this file is sourced by run.sh and must not replace its
# cleanup trap. LC_HOME is removed at the end of this file.

HOOKS_DIR="$PACK/shared/hooks"
# shellcheck source=shared/hooks/lib/fleet_install.sh
source "$HOOKS_DIR/lib/fleet_install.sh"
EXPECTED_HOOK_SH=$((3 + 6))

INSTALL1_EC=0
HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || INSTALL1_EC=$?
INSTALL2_EC=0
HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || INSTALL2_EC=$?
run_test "double install first pass exits 0" "0" "$INSTALL1_EC"
run_test "double install second pass exits 0" "0" "$INSTALL2_EC"

EVT="$(jq -r '.hooks | [has("beforeSubmitPrompt"),has("beforeShellExecution"),has("beforeReadFile")] | map(select(.)) | length' "$LC_HOME/.cursor/hooks.json" 2>/dev/null || echo 0)"
run_test "double install registers the 3 required events" "3" "$EVT"
STOP_EVT="$(jq -r '.hooks | has("stop")' "$LC_HOME/.cursor/hooks.json" 2>/dev/null || echo missing)"
run_test "regression: install does not register stop" "false" "$STOP_EVT"

CORE_HOME="$(test -f "$LC_HOME/.cursor/rules/core.mdc" && echo yes || echo no)"
run_test "install copies core.mdc into isolated HOME rules" "yes" "$CORE_HOME"
CHARTER_HOME="$(grep -q 'You are kleosr'"'"'s engineering partner' "$LC_HOME/.cursor/rules/kleosr.mdc" 2>/dev/null && echo yes || echo no)"
run_test "install writes kleosr.mdc charter into isolated HOME rules" "yes" "$CHARTER_HOME"
HUNTER_HOME="$(test -f "$LC_HOME/.cursor/agents/hunter.md" && echo yes || echo no)"
CUT_HOME="$(test -f "$LC_HOME/.cursor/agents/cut.md" && echo yes || echo no)"
PROVE_HOME="$(test -f "$LC_HOME/.cursor/agents/prove.md" && echo yes || echo no)"
ARCHITECT_HOME="$(test -f "$LC_HOME/.cursor/agents/architect.md" && echo yes || echo no)"
run_test "install copies hunter/cut/prove/architect agents" "yes" "$([[ "$HUNTER_HOME$CUT_HOME$PROVE_HOME$ARCHITECT_HOME" == yesyesyesyes ]] && echo yes || echo no)"
TESTING_SKILL="$(test -e "$LC_HOME/.cursor/skills/testing/SKILL.md" && echo yes || echo no)"
run_test "install links testing skill" "yes" "$TESTING_SKILL"
HANDOFF_SKILL="$(test -e "$LC_HOME/.cursor/skills/handoff/SKILL.md" && echo yes || echo no)"
run_test "install links handoff skill" "yes" "$HANDOFF_SKILL"
KLEOSR_SKILL="$(test -e "$LC_HOME/.cursor/skills/kleosr/SKILL.md" && echo yes || echo no)"
run_test "install links kleosr custom mode skill" "yes" "$KLEOSR_SKILL"
ARCH_GATE="$(test -f "$LC_HOME/.cursor/skills/code-architecture/scripts/quality-gate.mjs" && echo yes || echo no)"
run_test "install links code-architecture with its quality gate" "yes" "$ARCH_GATE"
CQRS_REF="$(test -f "$LC_HOME/.cursor/skills/cqrs-data-flow/references/request-contract.md" && echo yes || echo no)"
run_test "install links cqrs-data-flow references" "yes" "$CQRS_REF"
UI_REF="$(test -f "$LC_HOME/.cursor/skills/live-ui-sync/references/sidebar-modules.md" && echo yes || echo no)"
run_test "install links live-ui-sync references" "yes" "$UI_REF"
ROUTER="$(test -f "$LC_HOME/.cursor/skills/bridle-harness/SKILL.md" && test ! -d "$LC_HOME/.cursor/skills/bridle-harness/references" && echo yes || echo no)"
run_test "install links bridle-harness without a vendored law copy" "yes" "$ROUTER"
ANIMATE_SKILL="$(test -e "$LC_HOME/.cursor/skills/animate/SKILL.md" && echo yes || echo no)"
run_test "install does not link retired animate skill" "no" "$ANIMATE_SKILL"
mkdir -p "$PACK/shared/skills/animate" "$LC_HOME/.cursor/skills"
ln -s "$PACK/shared/skills/animate" "$LC_HOME/.cursor/skills/animate"
rm -rf "$PACK/shared/skills/animate"
HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1
ANIMATE_GONE="$(test -L "$LC_HOME/.cursor/skills/animate" && echo yes || echo no)"
run_test "regression: reinstall removes a retired animate symlink" "no" "$ANIMATE_GONE"
SHELL_FLEET="$(test -e "$LC_HOME/.cursor/hooks/lib/shell_fleet.sh" && echo yes || echo no)"
run_test "install does not ship v1 shell_fleet.sh" "no" "$SHELL_FLEET"
HOST_SH="$(test -e "$LC_HOME/.cursor/hooks/lib/host.sh" && echo yes || echo no)"
run_test "regression: install does not ship lib/host.sh" "no" "$HOST_SH"

HOOK_SH_COUNT="$(find "$LC_HOME/.cursor/hooks" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
run_test "double install hook script count matches (3 scripts + 6 libs)" "$EXPECTED_HOOK_SH" "$HOOK_SH_COUNT"
printf '%s\n' '#!/bin/sh' 'echo pack-stop' > "$LC_HOME/.cursor/hooks/stop.sh"
jq '.hooks.stop = [{command:"./hooks/stop.sh",timeout:30,failClosed:false,loop_limit:1}]' \
  "$LC_HOME/.cursor/hooks.json" > "$LC_HOME/.cursor/hooks.json.tmp"
mv "$LC_HOME/.cursor/hooks.json.tmp" "$LC_HOME/.cursor/hooks.json"
HOME="$LC_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1
STOP_GONE="$(test -f "$LC_HOME/.cursor/hooks/stop.sh" && echo yes || echo no)"
STOP_KEY="$(jq -r '.hooks | has("stop")' "$LC_HOME/.cursor/hooks.json" 2>/dev/null || echo missing)"
run_test "regression: reinstall deletes a leftover pack stop.sh" "no" "$STOP_GONE"
run_test "regression: reinstall drops a leftover pack stop registration" "false" "$STOP_KEY"

DUP_BASENAMES="$(find "$LC_HOME/.cursor/hooks" -name '*.sh' -exec basename {} \; 2>/dev/null | sort | uniq -d | wc -l | tr -d ' ')"
run_test "double install has no duplicate hook script basenames" "0" "$DUP_BASENAMES"

mkdir -p "$LC_HOME/.cursor/rules"
printf '%s\n' '---' 'alwaysApply: true' '---' '# user custom' > "$LC_HOME/.cursor/rules/my-custom.mdc"
UNINSTALL_EC=0
HOME="$LC_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || UNINSTALL_EC=$?
CUSTOM_OK="$(test -f "$LC_HOME/.cursor/rules/my-custom.mdc" && echo yes || echo no)"
HOOKS_GONE="$(test -f "$LC_HOME/.cursor/hooks.json" && echo no || echo yes)"
AGENT_GONE="$(test -f "$LC_HOME/.cursor/agents/hunter.md" && echo no || echo yes)"
HANDOFF_SKILL_GONE="$(test -e "$LC_HOME/.cursor/skills/handoff" && echo no || echo yes)"
CORE_GONE="$(test -f "$LC_HOME/.cursor/rules/core.mdc" && echo no || echo yes)"
CHARTER_GONE="$(test -f "$LC_HOME/.cursor/rules/kleosr.mdc" && echo no || echo yes)"
run_test "uninstall with FORCE unset exits 0" "0" "$UNINSTALL_EC"
run_test "uninstall removes hooks.json when only pack events remain" "yes" "$HOOKS_GONE"
run_test "uninstall removes kleosrules handoff skill" "yes" "$HANDOFF_SKILL_GONE"
run_test "uninstall removes core.mdc" "yes" "$CORE_GONE"
run_test "uninstall removes kleosr.mdc charter" "yes" "$CHARTER_GONE"
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
MERGE_EVT="$(jq -r '.hooks | [has("beforeSubmitPrompt"),has("beforeShellExecution"),has("beforeReadFile")] | map(select(.)) | length' "$MERGE_HOME/.cursor/hooks.json" 2>/dev/null || echo 0)"
MERGE_STOP="$(jq -r '.hooks | has("stop")' "$MERGE_HOME/.cursor/hooks.json" 2>/dev/null || echo missing)"
rm -rf "$MERGE_HOME"
run_test "install merge keeps pre-existing user hook entry" "1" "$MERGE_USER"
run_test "install merge adds pack before_shell entry" "1" "$MERGE_PACK"
run_test "install merge registers all 3 required events" "3" "$MERGE_EVT"
run_test "install merge does not register stop" "false" "$MERGE_STOP"

OWN_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-own.XXXXXX")"
mkdir -p "$OWN_HOME/.cursor/rules"
printf '%s\n' '# user core' > "$OWN_HOME/.cursor/rules/core.mdc"
HOME="$OWN_HOME" FORCE=0 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || true
OWN_SKIP="$(grep -q 'user core' "$OWN_HOME/.cursor/rules/core.mdc" 2>/dev/null && echo kept || echo replaced)"
HOME="$OWN_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || true
OWN_BAK="$(test -f "$OWN_HOME/.cursor/rules/core.mdc.pre-kleos-bak" && echo yes || echo no)"
HOME="$OWN_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || true
OWN_RESTORE="$(grep -q 'user core' "$OWN_HOME/.cursor/rules/core.mdc" 2>/dev/null && echo yes || echo no)"
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

CL_H="$(mktemp -d "${TMPDIR:-/tmp}/kleos-cl.XXXXXX")"
CL_EC=0
HOME="$CL_H" bash "$PACK/scripts/claude.sh" install >/dev/null 2>&1 || CL_EC=$?
run_test "claude port install exits 0" "0" "$CL_EC"
RESULT="$(grep -q 'You are kleosr'"'"'s engineering partner' "$CL_H/.claude/rules/kleosr.md" 2>/dev/null && echo yes || echo no)"
run_test "claude port writes the charter as rules/kleosr.md" "yes" "$RESULT"
RESULT="$(head -1 "$CL_H/.claude/rules/core.md" 2>/dev/null)"
run_test "claude port: always-on core.md has no frontmatter (loads every session)" "# Core" "$RESULT"
RESULT="$(grep -c '^  - "\*\*/app/\*\*"$' "$CL_H/.claude/rules/next.md" 2>/dev/null || true)"
run_test "regression: claude port quotes companion paths (bare * is a YAML alias)" "1" "$RESULT"
if grep -rq '\.mdc' "$CL_H/.claude/rules" "$CL_H/.claude/skills" "$CL_H/.claude/agents" 2>/dev/null; then RESULT=stale; else RESULT=ok; fi
run_test "claude port rewrites .mdc references to .md" "ok" "$RESULT"
RESULT="$(grep -c '^disallowedTools: Write, Edit, NotebookEdit$' "$CL_H/.claude/agents/hunter.md" 2>/dev/null || true)"
run_test "claude port maps readonly agents to denied write tools" "1" "$RESULT"
RESULT="$(grep -cE '^(mode|icon|color):' "$CL_H/.claude/skills/kleosr/SKILL.md" 2>/dev/null || true)"
run_test "claude port drops Cursor-only skill keys" "0" "$RESULT"
RESULT="$(test -f "$CL_H/.claude/skills/code-architecture/scripts/quality-gate.mjs" && test -f "$CL_H/.claude/skills/live-ui-sync/references/sidebar-modules.md" && echo yes || echo no)"
run_test "claude port ships skill references and the quality gate" "yes" "$RESULT"
printf '%s\n' '# user testing' > "$CL_H/.claude/rules/testing.md"
rm -f "$CL_H/.claude/kleosrules-owned.txt"
HOME="$CL_H" bash "$PACK/scripts/claude.sh" install >/dev/null 2>&1 || true
RESULT="$(grep -q 'user testing' "$CL_H/.claude/rules/testing.md" && echo kept || echo replaced)"
run_test "regression: claude port keeps an unowned rule without FORCE" "kept" "$RESULT"
HOME="$CL_H" FORCE=1 bash "$PACK/scripts/claude.sh" install >/dev/null 2>&1 || true
HOME="$CL_H" bash "$PACK/scripts/claude.sh" uninstall >/dev/null 2>&1 || true
RESULT="$(grep -q 'user testing' "$CL_H/.claude/rules/testing.md" 2>/dev/null && echo restored || echo lost)"
run_test "claude port uninstall restores the replaced user rule" "restored" "$RESULT"
RESULT="$(test -e "$CL_H/.claude/rules/kleosr.md" && echo present || echo gone)"
run_test "claude port uninstall removes owned files" "gone" "$RESULT"
RESULT="$(test -e "$CL_H/.claude/skills/code-architecture/scripts/quality-gate.mjs" && echo present || echo gone)"
run_test "claude port uninstall removes skill sidecars" "gone" "$RESULT"
rm -rf "$CL_H"

rm -rf "$LC_HOME"
