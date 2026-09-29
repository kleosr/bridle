#!/usr/bin/env bash
# Fleet helpers: manifest lists, path canon, ownership hashing, symlinks.

KLEOS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/lib/common.sh
source "$KLEOS_LIB_DIR/../../../hooks/lib/common.sh"
# shellcheck source=hosts/lib.sh
source "$KLEOS_LIB_DIR/../../lib.sh"

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
  # Git Bash `ln -s` copies directories unless winsymlinks:nativestrict.
  # Uninstall removes catalog skills only when they are real symlinks
  # (directory copies need FORCE=1).
  if (MSYS="${MSYS:+$MSYS }winsymlinks:nativestrict" ln -sfn "$src" "$dst") 2>/dev/null && [[ -L "$dst" ]]; then
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
  while IFS= read -r n; do
    [[ "$n" == "$stem" ]] && return 0
  done < <(manifest_list '.retiredSkills[]')
  return 1
}

# Old installers left retired skills as skills/<name>.pre-kleos-bak, which the
# host catalogs. Only retired stems are removed; foreign names are kept.
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
