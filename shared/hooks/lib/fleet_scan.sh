#!/usr/bin/env bash

load_lines() {
  local f="$1" line
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "$(printf '#')" ]] && continue
    printf '%s\n' "$line"
  done <"$f"
}

is_ignored() {
  local path="$1" base pat
  base="$(basename "$path")"
  while IFS= read -r pat; do
    [[ -z "$pat" ]] && continue
    [[ "$base" == "$pat" ]] && return 0
    [[ "$path" == *"/$pat/"* ]] && return 0
    [[ "$path" == */"$pat" ]] && return 0
  done < <(load_lines "$PACK/shared/config/scan.ignore")
  return 1
}

expand_path() {
  local p="$1" name value line tok
  p="${p/#\~/$HOME}"
  while IFS= read -r line; do
    name="${line%%=*}"
    value="${line#*=}"
    [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    tok="\${${name}}"
    p="${p//"$tok"/$value}"
    tok="\$${name}"
    p="${p//"$tok"/$value}"
  done < <(env)
  printf '%s\n' "$p"
}

is_project() {
  local d="$1"
  [[ -d "$d/.git" || -f "$d/package.json" || -f "$d/pnpm-workspace.yaml" \
    || -f "$d/Cargo.toml" || -f "$d/go.mod" || -f "$d/pyproject.toml" \
    || -f "$d/AGENTS.md" || -d "$d/.cursor/rules" ]]
}

canon() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"; }

symlink_force() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
}

discover() {
  local roots=() root child grand raw exp
  while IFS= read -r raw; do
    exp="$(expand_path "$raw")"
    [[ -d "$exp" ]] || continue
    roots+=("$(canon "$exp")")
  done < <(load_lines "$PACK/shared/config/scan.roots")
  if [[ ${#roots[@]} -eq 0 ]]; then
    return 0
  fi
  for root in "${roots[@]}"; do
    if is_project "$root" && ! is_ignored "$root"; then
      canon "$root"
    fi
    for child in "$root"/*/; do
      [[ -d "$child" ]] || continue
      child="${child%/}"
      is_ignored "$child" && continue
      if is_project "$child"; then canon "$child"; fi
      # depth-2: group folders like ~/Documents/<group>/<project>
      for grand in "$child"/*/; do
        [[ -d "$grand" ]] || continue
        grand="${grand%/}"
        is_ignored "$grand" && continue
        is_project "$grand" || continue
        canon "$grand"
      done
    done
  done | sort -u
}
