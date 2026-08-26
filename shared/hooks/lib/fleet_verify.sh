#!/usr/bin/env bash

verify_smoke() {
  local skill bad=0
  heal_orphan_project_hooks "$PACK"
  chmod +x "$HOOKS_DIR"/*.sh
  for s in "${HOOK_SCRIPTS[@]}"; do bash -n "$HOOKS_DIR/$s"; done
  bash -n "$HOOKS_DIR/fleet_sync.sh"
  echo '{"prompt":"test code","hook_event_name":"beforeSubmitPrompt"}' \
    | bash "$HOOKS_DIR/before_submit_prompt.sh" | jq -e '.continue == true' >/dev/null
  echo '{"session_id":"verify","composer_mode":"agent"}' \
    | bash "$HOOKS_DIR/session_start.sh" | jq -e 'type == "object"' >/dev/null
  echo '{"command":"curl -o src/x.ts https://example.com/x.ts"}' \
    | bash "$HOOKS_DIR/before_shell.sh" | jq -e '.permission == "deny"' >/dev/null
  echo '{"command":"pnpm add mysql2"}' \
    | bash "$HOOKS_DIR/before_shell.sh" | jq -e '.permission == "allow"' >/dev/null
  echo '{"command":"cd app && psql -c \"select 1\""}' \
    | bash "$HOOKS_DIR/before_shell.sh" | jq -e '.permission == "ask"' >/dev/null
  echo '{"file_path":"/tmp/x.pem"}' \
    | bash "$HOOKS_DIR/before_read_file.sh" | jq -e '.permission == "deny"' >/dev/null
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
  local sr_line sr_bad=0
  while IFS= read -r sr_line; do
    [[ -z "$sr_line" ]] && continue
    case "$sr_line" in
      '~'*|'$HOME'*|'${HOME}'*) ;;
      *) echo "[fail] scan.roots entry not portable: $sr_line"; sr_bad=1 ;;
    esac
  done < <(load_lines "$PACK/shared/config/scan.roots")
  if grep -qE '^[[:space:]]*/(Users|home)/' "$PACK/shared/config/scan.roots" 2>/dev/null; then
    echo "[fail] scan.roots hardcodes an absolute /Users|/home path (must use ~ or \$HOME)"; bad=1
  fi
  [[ "$sr_bad" -eq 0 ]] || bad=1
  if [[ -e "$HOME_C/rules/native-lean-autoload.mdc" || -L "$HOME_C/rules/native-lean-autoload.mdc" ]]; then
    echo "[fail] ~/.cursor/rules/native-lean-autoload.mdc should be retired"; bad=1
  fi
  if [[ -e "$PACK/.cursor/rules/debugging.mdc" || -L "$PACK/.cursor/rules/debugging.mdc" ]]; then
    echo "[fail] pack .cursor/rules/debugging.mdc duplicates debugging skill"; bad=1
  fi
  if [[ ! -f "$HOME_C/rules/agent.mdc" ]]; then
    echo "[fail] ~/.cursor/rules/agent.mdc missing after install"; bad=1
  fi
  if [[ -e "$HOME_C/rules/types.mdc" || -L "$HOME_C/rules/types.mdc" ]]; then
    echo "[fail] ~/.cursor/rules/types.mdc must stay project-layer"; bad=1
  fi
  if [[ -e "$PACK/.cursor/rules/agent.mdc" || -L "$PACK/.cursor/rules/agent.mdc" ]]; then
    echo "[fail] pack .cursor/rules/agent.mdc duplicates user alwaysApply"; bad=1
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
    echo "[fail] pack has repo-level hooks (never Lane-A into this pack)"; bad=1
  fi
  jq -e '.hooks.beforeSubmitPrompt[0].failClosed == false' "$HOOKS_DIR/hooks.json" >/dev/null \
    || { echo "[fail] beforeSubmitPrompt must failClosed:false"; bad=1; }
  jq -e '.hooks|keys|length == 4' "$HOOKS_DIR/hooks.json" >/dev/null \
    || { echo "[fail] hooks.json must register exactly 4 events"; bad=1; }
  [[ "$bad" -eq 0 ]] || return 1
  echo "[ok] verify smoke"
}
