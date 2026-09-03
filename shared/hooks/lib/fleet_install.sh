#!/usr/bin/env bash

HOOK_SCRIPTS=(session_start.sh before_submit_prompt.sh before_shell.sh before_read_file.sh)
CLOUD_HOOK_SCRIPTS=(before_shell.sh before_read_file.sh before_submit_prompt.sh)
RUNTIME_LIBS=(common.sh shell_gate.sh)
PACK_AGENTS=(hunter cut prove)

prune_hook_scripts() {
  local dest="$1" s b keep k
  shift
  for s in "$dest"/*.sh; do
    [[ -f "$s" ]] || continue
    b="$(basename "$s")"
    keep=0
    for k in "$@"; do
      [[ "$b" == "$k" ]] && keep=1 && break
    done
    [[ "$keep" -eq 1 ]] || rm -f "$s"
  done
}

copy_runtime_libs() {
  local dest="$1" s b keep k
  mkdir -p "$dest/lib"
  for s in "${RUNTIME_LIBS[@]}"; do
    cp -f "$HOOKS_DIR/lib/$s" "$dest/lib/$s"
    chmod +x "$dest/lib/$s"
  done
  for s in "$dest/lib"/*.sh; do
    [[ -f "$s" ]] || continue
    b="$(basename "$s")"
    keep=0
    for k in "${RUNTIME_LIBS[@]}"; do
      [[ "$b" == "$k" ]] && keep=1 && break
    done
    [[ "$keep" -eq 1 ]] || rm -f "$s"
  done
}

copy_hook_scripts() {
  local dest="$1" s p
  mkdir -p "$dest/policy" "$dest/lib"
  for s in "${HOOK_SCRIPTS[@]}"; do
    cp -f "$HOOKS_DIR/$s" "$dest/$s"
    chmod +x "$dest/$s"
  done
  copy_runtime_libs "$dest"
  for p in "$HOOKS_DIR"/policy/*; do
    [[ -f "$p" ]] || continue
    cp -f "$p" "$dest/policy/$(basename "$p")"
  done
  prune_hook_scripts "$dest" "${HOOK_SCRIPTS[@]}"
}

write_home_hooks_json() {
  cp -f "$HOOKS_DIR/hooks.json" "$HOME_C/hooks.json"
}

heal_orphan_project_hooks() {
  local repo="$1"
  if [[ -f "$repo/.cursor/hooks.json" && ! -f "$repo/.cursor/hooks/before_shell.sh" ]]; then
    rm -f "$repo/.cursor/hooks.json"
    rm -rf "$repo/.cursor/hooks"
    echo "[heal] orphan project hooks.json (scripts missing) → $repo"
  fi
}

assert_dest_hook_scripts() {
  local dest="$1" s
  for s in before_shell.sh before_read_file.sh before_submit_prompt.sh; do
    [[ -f "$dest/$s" ]] || return 1
  done
  return 0
}

install_home_hooks() {
  mkdir -p "$HOME_C/hooks/policy"
  copy_hook_scripts "$HOME_C/hooks"
  for orphan in ask-gated-shell.sh backlog-on-read.sh block-dangerous-git.sh capture-mistake.sh deny-danger.sh install-user-hooks.sh; do
    rm -f "$HOME_C/hooks/$orphan"
  done
  rm -rf "$HOME_C/hooks/bin" "$HOME_C/hooks/__pycache__"
  write_home_hooks_json
  echo "[ok] ~/.cursor/hooks.json + hooks scripts (global single layer)"
}

install_project_hooks() {
  local repo="$1" label="$2" dest s p rules_dest
  heal_orphan_project_hooks "$repo"
  dest="$repo/.cursor/hooks"
  mkdir -p "$dest/policy" "$dest/lib"
  for s in "${CLOUD_HOOK_SCRIPTS[@]}"; do
    cp -f "$HOOKS_DIR/$s" "$dest/$s"
    chmod +x "$dest/$s"
  done
  copy_runtime_libs "$dest"
  for p in "$HOOKS_DIR"/policy/*; do
    [[ -f "$p" ]] || continue
    cp -f "$p" "$dest/policy/$(basename "$p")"
  done
  prune_hook_scripts "$dest" "${CLOUD_HOOK_SCRIPTS[@]}"
  if ! assert_dest_hook_scripts "$dest"; then
    echo "[fail] refuse hooks.json — scripts missing under $dest"
    rm -rf "$dest"
    return 1
  fi
  cp -f "$HOOKS_DIR/hooks.cloud.json" "$repo/.cursor/hooks.json"
  rules_dest="$repo/.cursor/rules"
  mkdir -p "$rules_dest"
  for s in ${GLOBAL[@]+"${GLOBAL[@]}"} ${SHARED[@]+"${SHARED[@]}"}; do
    [[ -f "$PACK/shared/rules/${s}.mdc" ]] || continue
    cp -f "$PACK/shared/rules/${s}.mdc" "$rules_dest/${s}.mdc"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    if [[ -e "$rules_dest/$orphan" || -L "$rules_dest/$orphan" ]]; then
      rm -f "$rules_dest/$orphan"
      echo "[rm] $label/.cursor/rules/$orphan"
    fi
  done < <(load_lines "$PACK/shared/config/retired.txt")
  echo "[ok] project Lane-A hooks + .mdc → $label (no sessionStart; cloud-safe)"
}

uninstall_home_hooks() {
  local s p
  if [[ -f "$HOME_C/hooks.json" ]] && grep -q 'hooks/before_submit_prompt.sh' "$HOME_C/hooks.json"; then
    rm -f "$HOME_C/hooks.json"
    echo "[rm] ~/.cursor/hooks.json"
  fi
  for s in "${HOOK_SCRIPTS[@]}"; do rm -f "$HOME_C/hooks/$s"; done
  for s in "${RUNTIME_LIBS[@]}"; do rm -f "$HOME_C/hooks/lib/$s"; done
  for p in "$HOOKS_DIR"/policy/*; do rm -f "$HOME_C/hooks/policy/$(basename "$p")"; done
  rm -f "$HOME_C/hooks/wsl-shim.ps1"
  rmdir "$HOME_C/hooks/policy" "$HOME_C/hooks/lib" "$HOME_C/hooks" 2>/dev/null || true
}

uninstall_home() {
  local name skill dst
  uninstall_home_hooks
  for name in "${GLOBAL[@]}"; do rm -f "$HOME_C/rules/${name}.mdc"; done
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    dst="$HOME_C/skills/$skill"
    [[ -L "$dst" && "$(canon "$dst")" == "$(canon "$PACK/shared/skills/$skill")" ]] && rm -f "$dst"
  done < <(load_lines "$PACK/shared/config/skills.txt")
  for name in "${PACK_AGENTS[@]}"; do rm -f "$HOME_C/agents/${name}.md"; done
  rm -f "$PACK/.cursor/rules/types.mdc"
  echo "[done] uninstall: kleosrules artifacts removed from ~/.cursor (foreign rules/skills/agents untouched)"
}

remove_project_hooks() {
  local repo="$1" label="$2"
  if [[ -e "$repo/.cursor/hooks.json" || -d "$repo/.cursor/hooks" ]]; then
    rm -f "$repo/.cursor/hooks.json"
    rm -rf "$repo/.cursor/hooks"
    echo "[rm] repo-level hooks → $label (global ~/.cursor layer owns registration)"
  fi
}
