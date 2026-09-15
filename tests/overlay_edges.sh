#!/usr/bin/env bash
# Sourced by run.sh. BOM/CRLF stdin, retired .mdc absence, Windows shim merge.

BOM=$'\xEF\xBB\xBF'
RESULT="$(printf '%s' "${BOM}{\"file_path\":\"/repo/README.md\"}" | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "none"')"
run_test "regression: before_read_file UTF-8 BOM JSON allows normal source" "allow" "$RESULT"
RESULT="$(printf '%s' "${BOM}{\"file_path\":\"/repo/.env\"}" | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "none"')"
run_test "regression: before_read_file UTF-8 BOM JSON still denies .env" "deny" "$RESULT"
RESULT="$(printf '%s' "${BOM}not json" | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "none"')"
run_test "regression: before_read_file BOM plus non-JSON still denies" "deny" "$RESULT"
RESULT="$(printf '%s' $'{"file_path":"/repo/README.md"}\r' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "none"')"
run_test "regression: before_read_file CRLF JSON allows normal source" "allow" "$RESULT"
RESULT="$(printf '%s' "${BOM}{\"command\":\"git status\",\"cwd\":\"/tmp\"}" | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "regression: before_shell UTF-8 BOM JSON allows git status" "allow" "$RESULT"
RESULT="$(printf '%s' "${BOM}{\"prompt\":\"hello\"}" | bash "$PACK/shared/hooks/before_submit_prompt.sh" | jq -r '.continue')"
run_test "regression: before_submit UTF-8 BOM JSON continues" "true" "$RESULT"

SHIM_DEST="$(mktemp "${TMPDIR:-/tmp}/kleos-shim.XXXXXX")"
SHIM_CMD='powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\u\.cursor\hooks\git-bash-shim.ps1" before_read_file.sh'
SS_CMD='powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\u\.cursor\hooks\git-bash-shim.ps1" session_start.sh'
jq -n --arg r "$SHIM_CMD" --arg s "$SS_CMD" \
  '{version:1,hooks:{beforeReadFile:[{command:$r,timeout:10,failClosed:false}],sessionStart:[{command:$s,timeout:10,failClosed:false}]}}' \
  >"$SHIM_DEST"
SHIM_MERGE="$(jq --arg mode merge --slurpfile dest "$SHIM_DEST" -f "$PACK/shared/hooks/lib/hooks_json.jq" "$PACK/shared/hooks/hooks.json")"
SHIM_KEEP="$(printf '%s' "$SHIM_MERGE" | jq -r '.hooks.beforeReadFile[0].command' | grep -c 'git-bash-shim' || true)"
SHIM_FC="$(printf '%s' "$SHIM_MERGE" | jq -r '.hooks.beforeReadFile[0].failClosed')"
SHIM_N="$(printf '%s' "$SHIM_MERGE" | jq -r '.hooks.beforeReadFile | length')"
SHIM_UNIX="$(printf '%s' "$SHIM_MERGE" | jq -r '[.hooks.beforeReadFile[]?.command] | map(select(test("./hooks/before_read_file"))) | length')"
SHIM_SS="$(printf '%s' "$SHIM_MERGE" | jq -r '.hooks | has("sessionStart")')"
rm -f "$SHIM_DEST"
run_test "regression: merge keeps quoted git-bash-shim command" "1" "$SHIM_KEEP"
run_test "regression: merge applies pack failClosed true onto shim" "true" "$SHIM_FC"
run_test "regression: merge does not duplicate beforeReadFile entries" "1" "$SHIM_N"
run_test "regression: merge does not add unix ./hooks/ beside shim" "0" "$SHIM_UNIX"
run_test "regression: merge does not reactivate sessionStart" "false" "$SHIM_SS"

ABS_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-abs.XXXXXX")"
mkdir -p "$ABS_HOME/.cursor/rules"
for n in agent vibe ponytail types complexity; do
  printf '%s\n' '---' 'alwaysApply: true' '---' "# leftover $n" > "$ABS_HOME/.cursor/rules/${n}.mdc"
done
printf '%s\n' '---' 'alwaysApply: true' '---' '# keep me' > "$ABS_HOME/.cursor/rules/my-custom.mdc"
HOME="$ABS_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || true
ABS_CORE="$(test -f "$ABS_HOME/.cursor/rules/core.mdc" && echo yes || echo no)"
ABS_AGENT="$(test -f "$ABS_HOME/.cursor/rules/agent.mdc" && echo yes || echo no)"
ABS_VIBE="$(test -f "$ABS_HOME/.cursor/rules/vibe.mdc" && echo yes || echo no)"
ABS_CUSTOM="$(test -f "$ABS_HOME/.cursor/rules/my-custom.mdc" && echo yes || echo no)"
ABS_SS="$(jq -r '.hooks | has("sessionStart")' "$ABS_HOME/.cursor/hooks.json" 2>/dev/null || echo missing)"
rm -rf "$ABS_HOME"
run_test "regression: install copies core.mdc" "yes" "$ABS_CORE"
run_test "regression: install removes retired agent.mdc" "no" "$ABS_AGENT"
run_test "regression: install removes retired vibe.mdc" "no" "$ABS_VIBE"
run_test "regression: install keeps unrelated my-custom.mdc" "yes" "$ABS_CUSTOM"
run_test "regression: fresh install does not register sessionStart" "false" "$ABS_SS"

HOOKS_DIR="$PACK/shared/hooks"
# shellcheck source=shared/hooks/lib/hooks_json.sh
source "$HOOKS_DIR/lib/hooks_json.sh"
UNBLOCK_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-unblock.XXXXXX")"
mkdir -p "$UNBLOCK_HOME/.cursor/hooks"
cp -f "$PACK/shared/hooks/git-bash-shim.ps1" "$UNBLOCK_HOME/.cursor/hooks/git-bash-shim.ps1"
PS51='powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\u\.cursor\hooks\git-bash-shim.ps1"'
jq -n --arg r "$PS51 before_read_file.sh" --arg s "$PS51 before_shell.sh" --arg t "$PS51 stop.sh" \
  '{version:1,hooks:{beforeReadFile:[{command:$r,timeout:10,failClosed:true}],beforeShellExecution:[{command:$s,timeout:30,failClosed:true}],stop:[{command:$t,timeout:30,failClosed:false,loop_limit:1}]}}' \
  >"$UNBLOCK_HOME/.cursor/hooks.json"
merge_hooks_json "$UNBLOCK_HOME/.cursor/hooks.json" "$PACK/shared/hooks/hooks.json"
apply_pwsh_shim_hooks "$UNBLOCK_HOME/.cursor/hooks.json"
UB_HAS="$(jq -r '.hooks | has("beforeSubmitPrompt")' "$UNBLOCK_HOME/.cursor/hooks.json")"
UB_LAUNCH="$(jq -r '.hooks.beforeSubmitPrompt[0].command' "$UNBLOCK_HOME/.cursor/hooks.json")"
UB_SHIM="$(printf '%s' "$UB_LAUNCH" | grep -c 'git-bash-shim' || true)"
UB_LAUNCHER=0
printf '%s' "$UB_LAUNCH" | grep -q 'pwsh' && UB_LAUNCHER=1
printf '%s' "$UB_LAUNCH" | grep -qi 'powershell.exe' && UB_LAUNCHER=1
UB_PS51="$(jq -r '[.hooks[][]?.command] | map(select(test("(^|[[:space:]])powershell[[:space:]]"))) | length' "$UNBLOCK_HOME/.cursor/hooks.json")"
UB_FC="$(jq -r '.hooks.beforeSubmitPrompt[0].failClosed' "$UNBLOCK_HOME/.cursor/hooks.json")"
UB_SS="$(jq -r '.hooks | has("sessionStart")' "$UNBLOCK_HOME/.cursor/hooks.json")"
rm -rf "$UNBLOCK_HOME"
run_test "regression: submit missing after unblock is restored via pwsh shim" "true" "$UB_HAS"
run_test "regression: restored submit launcher uses git-bash-shim" "1" "$UB_SHIM"
run_test "regression: restored submit launcher is pwsh or powershell.exe" "1" "$UB_LAUNCHER"
run_test "regression: apply rewrites leftover powershell 5.1 launchers" "0" "$UB_PS51"
run_test "regression: restored submit stays failClosed true" "true" "$UB_FC"
run_test "regression: apply does not reactivate sessionStart" "false" "$UB_SS"

# Live Windows: powershell.exe -File must exit 0 on an allow (failClosed crash was exit 1).
PS_BIN=""
if command -v powershell.exe >/dev/null 2>&1; then
  PS_BIN="$(command -v powershell.exe)"
elif [[ -f /c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]]; then
  PS_BIN="/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
fi
if [[ -n "$PS_BIN" && -f "$PACK/shared/hooks/git-bash-shim.ps1" ]]; then
  SHIM_EC=0
  SHIM_OUT="$(printf '%s' '{"file_path":"/repo/README.md"}' | "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$PACK/shared/hooks/git-bash-shim.ps1" before_read_file.sh)" || SHIM_EC=$?
  SHIM_PERM="$(printf '%s' "$SHIM_OUT" | jq -r '.permission // "none"')"
  run_test "regression: git-bash-shim allow exits 0 (not failClosed crash)" "0" "$SHIM_EC"
  run_test "regression: git-bash-shim allow emits permission allow" "allow" "$SHIM_PERM"
fi
