#!/usr/bin/env bash

prune_project_names_from_home() {
  local name
  for name in ${SHARED[@]+"${SHARED[@]}"}; do
    if [[ -e "$HOME_C/rules/${name}.mdc" || -L "$HOME_C/rules/${name}.mdc" ]]; then
      rm -f "$HOME_C/rules/${name}.mdc"
      echo "[rm] ~/.cursor/rules/${name}.mdc (project layer)"
    fi
  done
}

prune_user_layer_from_project() {
  local dest="$1" name
  for name in ${GLOBAL[@]+"${GLOBAL[@]}"}; do
    if [[ -e "$dest/${name}.mdc" || -L "$dest/${name}.mdc" ]]; then
      rm -f "$dest/${name}.mdc"
      echo "[rm] ${dest}/${name}.mdc (user layer)"
    fi
  done
}

install_global_rules() {
  local name orphan
  mkdir -p "$HOME_C/rules"
  for name in "${GLOBAL[@]}"; do
    cp -f "$PACK/shared/rules/${name}.mdc" "$HOME_C/rules/${name}.mdc"
    echo "[ok] ~/.cursor/rules/${name}.mdc"
  done
  prune_project_names_from_home
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    if [[ -e "$HOME_C/rules/$orphan" || -L "$HOME_C/rules/$orphan" ]]; then
      rm -f "$HOME_C/rules/$orphan"
      echo "[rm] ~/.cursor/rules/$orphan"
    fi
  done < <(load_lines "$PACK/shared/config/retired.txt")
}

install_skills() {
  local skill src dst
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
      rm -f "$dst"
      echo "[rm] retired skill $skill"
    fi
  done < <(load_lines "$PACK/shared/config/retired-skills.txt")
  return 0
}

link_pack_rules() {
  local dest="$PACK/.cursor/rules" name orphan
  mkdir -p "$dest"
  prune_user_layer_from_project "$dest"
  for name in ${SHARED[@]+"${SHARED[@]}"}; do
    [[ -f "$PACK/shared/rules/${name}.mdc" ]] || continue
    symlink_force "../../shared/rules/${name}.mdc" "$dest/${name}.mdc"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    if [[ -e "$dest/$orphan" || -L "$dest/$orphan" ]]; then
      rm -f "$dest/$orphan"
      echo "[rm] pack/$orphan"
    fi
  done < <(load_lines "$PACK/shared/config/retired.txt")
  echo "[ok] pack .cursor/rules → shared/rules (project layer)"
}

gitignore_state() {
  local repo="$1" gi="$repo/.gitignore"
  [[ -f "$gi" ]] || touch "$gi"
  grep -qxF 'state/' "$gi" || printf '\n# kleosrules runtime state (velocity log, intent snapshots)\nstate/\n' >>"$gi"
}

sync_repo_hooks() {
  local repo="$1" label="$2"
  if [[ "$(canon "$repo")" == "$(canon "$PACK")" ]]; then
    remove_project_hooks "$repo" "$label"
  fi
  gitignore_state "$repo"
}

sync_repo_rules() {
  local repo="$1" label="$2" dest name orphan
  dest="$repo/.cursor/rules"
  mkdir -p "$dest"
  prune_user_layer_from_project "$dest"
  for name in ${SHARED[@]+"${SHARED[@]}"}; do
    [[ -f "$PACK/shared/rules/${name}.mdc" ]] || continue
    rm -f "$dest/${name}.mdc"
    cp -f "$PACK/shared/rules/${name}.mdc" "$dest/${name}.mdc"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    if [[ -e "$dest/$orphan" || -L "$dest/$orphan" ]]; then
      rm -f "$dest/$orphan"
      echo "[rm] $label/$orphan"
    fi
  done < <(load_lines "$PACK/shared/config/retired.txt")
  echo "[ok] rules → $label (project layer)"
}

sync_fleet() {
  local pack_c repos=() repo label line
  pack_c="$(canon "$PACK")"
  while IFS= read -r line; do repos+=("$line"); done < <(discover)
  echo "[scan] ${#repos[@]} project(s)"
  link_pack_rules
  sync_repo_hooks "$PACK" "pack"
  for repo in ${repos[@]+"${repos[@]}"}; do
    [[ "$repo" == "$pack_c" ]] && continue
    label="$(basename "$repo")"
    sync_repo_rules "$repo" "$label"
    sync_repo_hooks "$repo" "$label"
  done
}
