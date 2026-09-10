#!/usr/bin/env bash
# Fleet install: home hooks + user rules + skills + agents, or opt-in
# project-hooks for the cloud lane. Idempotent; FORCE=1 owns differences.

# shellcheck source=shared/hooks/lib/hooks_json.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hooks_json.sh"

HOOK_SCRIPTS=(before_submit_prompt.sh before_shell.sh before_read_file.sh stop.sh)
CLOUD_HOOK_SCRIPTS=(before_shell.sh before_read_file.sh before_submit_prompt.sh)

manifest_list() { jq -r "$1" "$(manifest_json)" 2>/dev/null; }

copy_runtime_libs() {
  local dest="$1" s b keep k libs
  libs="$(manifest_list '.runtimeLibs[]')"
  mkdir -p "$dest/lib"
  while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    cp -f "$HOOKS_DIR/lib/$s" "$dest/lib/$s"
    chmod +x "$dest/lib/$s"
  done <<<"$libs"
  for s in "$dest/lib"/*.sh; do
    [[ -f "$s" ]] || continue
    b="$(basename "$s")"
    keep=0
    while IFS= read -r k; do
      [[ -z "$k" ]] && continue
      [[ "$b" == "$k" ]] && keep=1 && break
    done <<<"$libs"
    [[ "$keep" -eq 1 ]] || rm -f "$s"
  done
}

copy_hook_scripts() {
  local dest="$1" s p legacy
  mkdir -p "$dest/policy" "$dest/lib"
  for s in "${HOOK_SCRIPTS[@]}"; do
    cp -f "$HOOKS_DIR/$s" "$dest/$s"
    chmod +x "$dest/$s"
  done
  while IFS= read -r legacy; do
    [[ -z "$legacy" ]] && continue
    rm -f "$dest/$legacy"
  done < <(manifest_list '.legacyCleanup[]')
  copy_runtime_libs "$dest"
  for p in "$HOOKS_DIR"/policy/*; do
    [[ -f "$p" ]] || continue
    cp -f "$p" "$dest/policy/$(basename "$p")"
  done
}

write_home_hooks_json() {
  merge_hooks_json "$HOME_C/hooks.json" "$HOOKS_DIR/hooks.json"
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
  rm -rf "$HOME_C/hooks/bin" "$HOME_C/hooks/__pycache__"
  write_home_hooks_json
  echo "[ok] ~/.cursor/hooks.json + hooks scripts (global single layer)"
}

install_global_rules() {
  local name orphan src dst h
  mkdir -p "$HOME_C/rules"
  : >"$HOME_C/kleosrules-owned.txt"
  for name in "${GLOBAL[@]}"; do
    src="$PACK/shared/rules/${name}.mdc"
    dst="$HOME_C/rules/${name}.mdc"
    [[ -f "$src" ]] || { echo "[fail] missing $src"; return 1; }
    if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst" 2>/dev/null; then
      if [[ "$FORCE" != "1" ]]; then
        echo "[warn] skip differing $dst (FORCE=1 to replace; backup kept)"
        continue
      fi
      if [[ ! -f "$dst.pre-kleos-bak" ]]; then
        cp -f "$dst" "$dst.pre-kleos-bak"
        echo "[bak] $dst.pre-kleos-bak"
      fi
    fi
    cp -f "$src" "$dst"
    echo "[ok] ~/.cursor/rules/${name}.mdc"
    h="$(owned_hash "$dst")"
    [[ -n "$h" ]] && printf 'rules/%s.mdc %s\n' "$name" "$h" >>"$HOME_C/kleosrules-owned.txt"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    if [[ -e "$HOME_C/rules/$orphan" || -L "$HOME_C/rules/$orphan" ]]; then
      rm -f "$HOME_C/rules/$orphan"
      echo "[rm] ~/.cursor/rules/$orphan"
    fi
  done < <(load_lines "$PACK/shared/config/retired.txt")
}

install_skills() {
  local skill src dst tgt
  mkdir -p "$HOME_C/skills"
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    src="$PACK/shared/skills/$skill"
    [[ -f "$src/SKILL.md" ]] || { echo "[fail] missing $src/SKILL.md"; return 1; }
    dst="$HOME_C/skills/$skill"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      if [[ "$FORCE" == "1" ]]; then
        rm -rf "$dst"
        echo "[force] replaced: $skill"
      else
        echo "[warn] skip non-symlink: $dst (FORCE=1)"
        continue
      fi
    fi
    symlink_force "$src" "$dst"
    echo "[ok] skill $skill"
  done < <(load_lines "$PACK/shared/config/skills.txt")
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    dst="$HOME_C/skills/$skill"
    if [[ -L "$dst" ]]; then
      tgt="$(readlink "$dst" 2>/dev/null || true)"
      if [[ "$tgt" == *"/kleosrules/"* || "$tgt" == "$PACK/shared/skills/$skill" ]]; then
        rm -f "$dst"
        echo "[rm] retired skill $skill"
      else
        echo "[keep] $dst (symlink not owned by this pack)"
      fi
    fi
  done < <(load_lines "$PACK/shared/config/retired-skills.txt")
  prune_skill_catalog_backups "$HOME_C/skills"
  return 0
}

install_agents() {
  local a src dst h
  mkdir -p "$HOME_C/agents"
  for a in hunter cut prove; do
    src="$PACK/shared/agents/${a}.md"
    dst="$HOME_C/agents/${a}.md"
    [[ -f "$src" ]] || { echo "[fail] missing shared/agents/${a}.md"; return 1; }
    if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst" 2>/dev/null; then
      if [[ "$FORCE" != "1" ]]; then
        echo "[warn] skip differing $dst (FORCE=1 to replace)"
        continue
      fi
      [[ -f "$dst.pre-kleos-bak" ]] || cp -f "$dst" "$dst.pre-kleos-bak"
    fi
    cp -f "$src" "$dst"
    echo "[ok] ~/.cursor/agents/${a}.md"
    h="$(owned_hash "$dst")"
    [[ -n "$h" ]] && printf 'agents/%s.md %s\n' "$a" "$h" >>"$HOME_C/kleosrules-owned.txt"
  done
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
  if ! assert_dest_hook_scripts "$dest"; then
    echo "[fail] refuse hooks.json — scripts missing under $dest"
    rm -rf "$dest"
    return 1
  fi
  cp -f "$HOOKS_DIR/hooks.cloud.json" "$repo/.cursor/hooks.json"
  rules_dest="$repo/.cursor/rules"
  mkdir -p "$rules_dest"
  for s in ${GLOBAL[@]+"${GLOBAL[@]}"}; do
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
  echo "[ok] project hooks + .mdc → $label (cloud-safe)"
}
