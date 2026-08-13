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
  local roots=() root child
  while IFS= read -r line; do roots+=("$line"); done < <(load_lines "$PACK/shared/config/scan.roots")
  if [[ ${#roots[@]} -eq 0 ]]; then
    roots=("$(dirname "$PACK")")
  fi
  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue
    if is_project "$root" && ! is_ignored "$root"; then
      canon "$root"
    fi
    for child in "$root"/*/; do
      [[ -d "$child" ]] || continue
      child="${child%/}"
      is_ignored "$child" && continue
      is_project "$child" || continue
      canon "$child"
    done
  done | sort -u
}
