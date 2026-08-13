#!/usr/bin/env bash

RESULT="$(cat "$PACK/tests/fixtures/preToolUse_shell_destructive.json" | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution blocks destructive command" "deny" "$RESULT"

RESULT="$(echo '{"command":"ls -la","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution allows safe command" "allow" "$RESULT"

RESULT="$(echo '{"command":"cat > src/x.ts <<EOF\n consoles\nEOF","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution denies cat> source write" "deny" "$RESULT"

RESULT="$(echo '{"command":"tee frontend/SectionNav.tsx","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution denies tee source write" "deny" "$RESULT"

RESULT="$(echo '{"command":"bash tests/run.sh","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution allows tests/run.sh" "allow" "$RESULT"

RESULT="$(echo '{"command":"sed -i s/a/b/ src/app.ts","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution denies sed -i source" "deny" "$RESULT"

RESULT="$(echo '{"command":"python -c \"open('\''x.ts'\'','\''w'\'').write('\''z'\'')\"","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution denies python -c write" "deny" "$RESULT"

RESULT="$(echo '{"command":"rg -n TODO src/","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution allows rg read-only" "allow" "$RESULT"

RESULT="$(echo '{"command":"curl -o src/x.ts https://example.com/x.ts","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution denies curl -o source" "deny" "$RESULT"

RESULT="$(echo '{"command":"git checkout -- src/app.ts","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution denies git checkout source" "deny" "$RESULT"

RESULT="$(echo '{"command":"terraform apply","cwd":"/tmp"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "none"')"
run_test "beforeShellExecution asks on terraform apply" "ask" "$RESULT"

SUBMIT_FC="$(jq -r '.hooks.beforeSubmitPrompt[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeSubmitPrompt failClosed is false" "false" "$SUBMIT_FC"

CLOUD_SHELL="$(jq -e '.hooks.beforeShellExecution' "$PACK/shared/hooks/hooks.cloud.json" >/dev/null && echo ok || echo no)"
run_test "hooks.cloud.json registers beforeShellExecution" "ok" "$CLOUD_SHELL"

READ_FC="$(jq -r '.hooks.beforeReadFile[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeReadFile failClosed is true" "true" "$READ_FC"

SHELL_FC="$(jq -r '.hooks.beforeShellExecution[0].failClosed' "$PACK/shared/hooks/hooks.json")"
run_test "beforeShellExecution failClosed is false" "false" "$SHELL_FC"

RESULT="$(echo '{"file_path":"/tmp/x.pem"}' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "allow"')"
run_test "before_read_file blocks pem" "deny" "$RESULT"

RESULT="$(echo '{"file_path":"/home/user/.env","hook_event_name":"beforeReadFile"}' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r '.permission // "allow"')"
run_test "before_read_file blocks .env from model context" "deny" "$RESULT"

RESULT="$(echo '{"file_path":"/home/user/src/app.ts","hook_event_name":"beforeReadFile"}' | bash "$PACK/shared/hooks/before_read_file.sh" | jq -r 'if . == {} then "allow" else (.permission // "allow") end')"
run_test "before_read_file allows normal source" "allow" "$RESULT"

CLOUD_FC="$(jq -r '.hooks.beforeSubmitPrompt[0].failClosed' "$PACK/shared/hooks/hooks.cloud.json")"
run_test "cloud beforeSubmitPrompt failClosed is false" "false" "$CLOUD_FC"

FS_HOME2="$(mktemp -d)"
TMP_REPO="$(mktemp -d)"
mkdir -p "$TMP_REPO/.git"
RESULT="$(HOME="$FS_HOME2" FORCE=1 CLOUD=1 TARGET_REPO="$TMP_REPO" bash "$PACK/shared/hooks/fleet_sync.sh" project-hooks >/dev/null 2>&1; echo $?)"
CLOUD_OK="$(test -f "$TMP_REPO/.cursor/hooks.json" && jq -e '.hooks|has("sessionStart")|not' "$TMP_REPO/.cursor/hooks.json" >/dev/null && echo yes || echo no)"
CLOUD_SH="$(grep -c before_shell "$TMP_REPO/.cursor/hooks.json" 2>/dev/null || true)"
CLOUD_SH="${CLOUD_SH//[!0-9]}"; [[ -z "$CLOUD_SH" ]] && CLOUD_SH=0
CLOUD_VERN="$(test -f "$TMP_REPO/.cursor/hooks/policy/vernacular_bans.txt" && echo yes || echo no)"
if [[ -e "$PACK/.cursor/hooks.json" || -d "$PACK/.cursor/hooks" ]]; then PACK_LEFT=yes; else PACK_LEFT=no; fi
rm -rf "$FS_HOME2" "$TMP_REPO"
run_test "fleet_sync project-hooks completes" "0" "$RESULT"
run_test "project-hooks omits sessionStart (no double DUTY)" "yes" "$CLOUD_OK"
run_test "project-hooks includes before_shell" "1" "$CLOUD_SH"
run_test "project-hooks copies vernacular_bans.txt" "yes" "$CLOUD_VERN"
run_test "project-hooks does not install into pack" "no" "$PACK_LEFT"

FS_HOME4="$(mktemp -d)"
RESULT="$(HOME="$FS_HOME4" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" project-hooks >/dev/null 2>&1; echo $?)"
if [[ -e "$PACK/.cursor/hooks.json" || -d "$PACK/.cursor/hooks" ]]; then PACK_PH=yes; else PACK_PH=no; fi
rm -rf "$FS_HOME4"
run_test "project-hooks requires TARGET_REPO" "2" "$RESULT"
run_test "project-hooks without TARGET_REPO does not install into pack" "no" "$PACK_PH"

ORPH="$(mktemp -d)"
mkdir -p "$ORPH/.cursor/hooks"
printf '{}\n' > "$ORPH/.cursor/hooks.json"
HEALED="$(
  source "$PACK/shared/hooks/lib/fleet_install.sh"
  heal_orphan_project_hooks "$ORPH" >/dev/null
  if [[ -f "$ORPH/.cursor/hooks.json" ]]; then echo yes; else echo no; fi
)"
rm -rf "$ORPH"
run_test "heal_orphan removes hooks.json when scripts missing" "no" "$HEALED"

RESULT="$(echo '{"command":"FORCE=1 bash shared/hooks/fleet_sync.sh install"}' | bash "$PACK/shared/hooks/before_shell.sh" | jq -r '.permission // "allow"')"
run_test "beforeShellExecution allows fleet_sync.sh install" "allow" "$RESULT"

FS_HOME3="$(mktemp -d)"
HOME="$FS_HOME3" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1
REL_CMD="$(jq -r '.hooks[][]?.command // empty' "$FS_HOME3/.cursor/hooks.json" 2>/dev/null | grep -c '^\.cursor/hooks/' || true)"
REL_CMD="${REL_CMD//[!0-9]}"; [[ -z "$REL_CMD" ]] && REL_CMD=0
DOT_CMD="$(jq -r '.hooks[][]?.command // empty' "$FS_HOME3/.cursor/hooks.json" 2>/dev/null | grep -c '^\./hooks/' || true)"
DOT_CMD="${DOT_CMD//[!0-9]}"; [[ -z "$DOT_CMD" ]] && DOT_CMD=0
HOME_EVT="$(jq -r '.hooks|keys|length' "$FS_HOME3/.cursor/hooks.json" 2>/dev/null || echo 0)"
rm -rf "$FS_HOME3"
run_test "home hooks.json has no project-relative .cursor/hooks/ commands" "0" "$REL_CMD"
run_test "home hooks.json uses ./hooks/ commands" "4" "$DOT_CMD"
run_test "home hooks.json has 4 events" "4" "$HOME_EVT"
