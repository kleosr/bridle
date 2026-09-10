#!/usr/bin/env bash

load_lines() {
  local f="$1" line
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "$(printf '#')" ]] && continue
    printf '%s\n' "$line"
  done <"$f"
}

canon() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"; }

owned_hash() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
  fi
}

symlink_force() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if ln -sfn "$src" "$dst" 2>/dev/null && [[ -e "$dst" || -L "$dst" ]]; then
    return 0
  fi
  rm -rf "$dst"
  if [[ -d "$src" ]]; then
    cp -R "$src" "$dst"
  else
    cp -f "$src" "$dst"
  fi
}

is_retired_skill_stem() {
  local stem="$1" n
  [[ -n "${PACK:-}" && -f "$PACK/shared/config/retired-skills.txt" ]] || return 1
  while IFS= read -r n; do
    [[ "$n" == "$stem" ]] && return 0
  done < <(load_lines "$PACK/shared/config/retired-skills.txt")
  return 1
}

# Pack installer used to leave retired skills as ~/.cursor/skills/<name>.pre-kleos-bak.
# Only those stems (retired-skills.txt) are removed from the catalog tree. Other names stay.
prune_skill_catalog_backups() {
  local root="${1:-$HOME_C/skills}" dst base stem
  for dst in "$root"/*.pre-kleos-bak; do
    [[ -e "$dst" || -L "$dst" ]] || continue
    base="$(basename "$dst")"
    stem="${base%.pre-kleos-bak}"
    if ! is_retired_skill_stem "$stem"; then
      echo "[keep] $dst (not a pack retired-skill leftover)"
      continue
    fi
    rm -rf "$dst"
    echo "[rm] skill catalog leftover $base"
  done
}
