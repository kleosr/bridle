#!/usr/bin/env bash

HOOK_SCRIPTS=(session_start.sh before_submit_prompt.sh before_shell.sh before_read_file.sh)
CLOUD_HOOK_SCRIPTS=(before_shell.sh before_read_file.sh before_submit_prompt.sh)
RUNTIME_LIBS=(common.sh shell_gate.sh shell_fleet.sh)

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
  mkdir -p "$HOME_C/hooks/policy" "$HOME_C/state"
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
  echo "[ok] project Lane-A hooks + .mdc → $label (no sessionStart; cloud-safe)"
}

remove_project_hooks() {
  local repo="$1" label="$2"
  if [[ -e "$repo/.cursor/hooks.json" || -d "$repo/.cursor/hooks" ]]; then
    rm -f "$repo/.cursor/hooks.json"
    rm -rf "$repo/.cursor/hooks"
    echo "[rm] repo-level hooks → $label (global ~/.cursor layer owns registration)"
  fi
}
