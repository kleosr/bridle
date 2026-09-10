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
  local name orphan src dst h
  mkdir -p "$HOME_C/rules"
  : >"$HOME_C/kleosrules-owned.txt"
  for name in "${GLOBAL[@]}"; do
    src="$PACK/shared/rules/${name}.mdc"
    dst="$HOME_C/rules/${name}.mdc"
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
