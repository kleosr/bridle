#!/usr/bin/env bash
# Install smoke: hook fixtures, ownership, catalog shape. Exits non-zero on failure.

verify_smoke() {
  local skill bad=0
  heal_orphan_project_hooks "$PACK"
  chmod +x "$HOOKS_DIR"/*.sh
  for s in "${HOOK_SCRIPTS[@]}"; do bash -n "$HOOKS_DIR/$s"; done
  bash -n "$HOOKS_DIR/fleet_sync.sh"
  echo '{"prompt":"test code","hook_event_name":"beforeSubmitPrompt"}' \
    | bash "$HOOKS_DIR/before_submit_prompt.sh" | jq -e '.continue == true' >/dev/null
  echo '{"command":"curl -o src/x.ts https://example.com/x.ts"}' \
    | bash "$HOOKS_DIR/before_shell.sh" | jq -e '.permission == "deny"' >/dev/null
  echo '{"command":"pnpm add mysql2"}' \
    | bash "$HOOKS_DIR/before_shell.sh" | jq -e '.permission == "allow"' >/dev/null
  echo '{"command":"npx eslint --rule complexity:off src/a.ts"}' \
    | bash "$HOOKS_DIR/before_shell.sh" | jq -e '.permission == "deny"' >/dev/null
  echo '{"command":"cd app && psql -c \"select 1\"","cwd":"/repo"}' \
    | bash "$HOOKS_DIR/before_shell.sh" | jq -e '.permission == "ask"' >/dev/null
  echo '{"file_path":"/tmp/x.pem"}' \
    | bash "$HOOKS_DIR/before_read_file.sh" | jq -e '.permission == "deny"' >/dev/null
  echo '{"command":"cat ~/.ssh/id_rsa"}' \
    | bash "$HOOKS_DIR/before_shell.sh" | jq -e '.permission == "deny"' >/dev/null
  echo '{"status":"aborted","loop_count":0}' \
    | bash "$HOOKS_DIR/stop.sh" | jq -e '. == {}' >/dev/null
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    if [[ ! -L "$HOME_C/skills/$skill" ]]; then
      echo "[fail] skill not symlink: $skill"; bad=1
    elif [[ "$(canon "$HOME_C/skills/$skill")" != "$(canon "$PACK/shared/skills/$skill")" ]]; then
      echo "[fail] skill wrong target: $skill -> $(readlink "$HOME_C/skills/$skill")"; bad=1
    fi
  done < <(load_lines "$PACK/shared/config/skills.txt")
  if [[ ! -f "$HOME_C/hooks/policy/secret_paths.ere" ]]; then
    echo "[fail] ~/.cursor/hooks/policy/secret_paths.ere missing after install"; bad=1
  fi
  if [[ ! -f "$HOME_C/hooks/policy/secret_tokens.ere" ]]; then
    echo "[fail] ~/.cursor/hooks/policy/secret_tokens.ere missing after install"; bad=1
  fi
  if [[ -f "$HOME_C/hooks/lib/shell_fleet.sh" ]]; then
    echo "[fail] v1 lib shell_fleet.sh still installed (must be pruned on upgrade)"; bad=1
  fi
  if [[ ! -f "$HOME_C/rules/agent.mdc" ]]; then
    echo "[fail] ~/.cursor/rules/agent.mdc missing after install"; bad=1
  fi
  if [[ ! -f "$HOME_C/rules/types.mdc" ]]; then
    echo "[fail] ~/.cursor/rules/types.mdc missing after install"; bad=1
  fi
  if [[ -e "$PACK/.cursor/rules/agent.mdc" || -L "$PACK/.cursor/rules/agent.mdc" ]]; then
    echo "[fail] pack .cursor/rules/agent.mdc duplicates user alwaysApply"; bad=1
  fi
  if [[ -e "$PACK/.cursor/rules/types.mdc" || -L "$PACK/.cursor/rules/types.mdc" ]]; then
    echo "[fail] pack .cursor/rules/types.mdc duplicates user alwaysApply"; bad=1
  fi
  if ! grep -q 'hooks/before_submit_prompt.sh' "$HOME_C/hooks.json" 2>/dev/null; then
    echo "[fail] ~/.cursor/hooks.json missing beforeSubmitPrompt (global layer broken)"; bad=1
  fi
  if grep -q 'kleos-gate' "$HOME_C/hooks.json" 2>/dev/null; then
    echo "[fail] home hooks still kleos-gate"; bad=1
  fi
  if grep -qE '^\s*"command":\s*"\.cursor/hooks/' "$HOME_C/hooks.json" 2>/dev/null; then
    echo "[fail] home hooks.json has project-relative .cursor/hooks/ commands"; bad=1
  fi
  if [[ -e "$PACK/.cursor/hooks.json" || -d "$PACK/.cursor/hooks" ]]; then
    echo "[fail] pack has repo-level hooks (never install into this pack)"; bad=1
  fi
  jq -e '.hooks.beforeSubmitPrompt[0].failClosed == true' "$HOOKS_DIR/hooks.json" >/dev/null \
    || { echo "[fail] beforeSubmitPrompt must failClosed:true"; bad=1; }
  jq -e '.hooks.beforeShellExecution[0].failClosed == true' "$HOOKS_DIR/hooks.json" >/dev/null \
    || { echo "[fail] beforeShellExecution must failClosed:true"; bad=1; }
  jq -e '.hooks.beforeReadFile[0].failClosed == true' "$HOOKS_DIR/hooks.json" >/dev/null \
    || { echo "[fail] beforeReadFile must failClosed:true"; bad=1; }
  jq -e '.hooks.beforeSubmitPrompt and .hooks.beforeShellExecution and .hooks.beforeReadFile and .hooks.stop' "$HOOKS_DIR/hooks.json" >/dev/null \
    || { echo "[fail] hooks.json must register beforeSubmitPrompt, beforeShellExecution, beforeReadFile, stop"; bad=1; }
  jq -e '.hooks|has("sessionStart")|not' "$HOOKS_DIR/hooks.json" >/dev/null \
    || { echo "[fail] hooks.json must not register sessionStart"; bad=1; }
  jq -e '.hooks.stop[0].loop_limit == 1' "$HOOKS_DIR/hooks.json" >/dev/null \
    || { echo "[fail] stop must be bounded: loop_limit 1"; bad=1; }
  [[ "$bad" -eq 0 ]] || return 1
  echo "[ok] verify smoke"
}
