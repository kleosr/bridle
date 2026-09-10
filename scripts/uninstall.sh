#!/usr/bin/env bash
# Remove kleosrules-owned artifacts from ~/.cursor only. Preserves unknown hooks.json keys and entries.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$PACK/shared/hooks"
HOME_C="${HOME}/.cursor"
source "$HOOKS_DIR/lib/fleet_scan.sh"
source "$HOOKS_DIR/lib/hooks_json.sh"
GLOBAL=()
while IFS= read -r _g; do
  GLOBAL+=("$_g")
done < <(load_lines "$PACK/shared/config/rules.global.txt")

if [[ -f "$HOME_C/hooks.json" ]]; then
  strip_owned_hooks_json "$HOME_C/hooks.json"
fi
remove_owned_hook_files "$HOME_C/hooks"

owned_ok() {
  local rel="$1" dst="$2" want have
  want="$(awk -v k="$rel" '$1==k{print $2; exit}' "$HOME_C/kleosrules-owned.txt" 2>/dev/null || true)"
  have="$(owned_hash "$dst" 2>/dev/null || true)"
  if [[ -n "$want" && -n "$have" ]]; then
    [[ "$want" == "$have" ]]
    return $?
  fi
  cmp -s "$PACK/shared/rules/$(basename "$rel")" "$dst" 2>/dev/null \
    || cmp -s "$PACK/shared/agents/$(basename "$rel")" "$dst" 2>/dev/null
}

restore_bak() {
  local dst="$1"
  if [[ -f "$dst.pre-kleos-bak" ]]; then
    mv -f "$dst.pre-kleos-bak" "$dst"
    echo "[restore] $dst from pre-kleos backup"
  fi
}

for name in "${GLOBAL[@]}"; do
  dst="$HOME_C/rules/${name}.mdc"
  if [[ -f "$dst" ]]; then
    if owned_ok "rules/${name}.mdc" "$dst"; then
      rm -f "$dst"
      echo "[rm] ~/.cursor/rules/${name}.mdc"
      restore_bak "$dst"
    else
      echo "[keep] differing ~/.cursor/rules/${name}.mdc (not owned)"
    fi
  fi
done

while IFS= read -r skill; do
  [[ -z "$skill" ]] && continue
  dst="$HOME_C/skills/$skill"
  if [[ -L "$dst" ]]; then
    target="$(readlink "$dst" 2>/dev/null || true)"
    if [[ "$target" == *"/kleosrules/"* || "$target" == "$PACK/shared/skills/$skill" ]]; then
      rm -f "$dst"
      echo "[rm] ~/.cursor/skills/$skill (symlink)"
    fi
  elif [[ -d "$dst" ]] && [[ "${FORCE:-0}" == "1" ]]; then
    rm -rf "$dst"
    echo "[rm] ~/.cursor/skills/$skill (FORCE=1 directory copy)"
  fi
done < <(load_lines "$PACK/shared/config/skills.txt")
prune_skill_catalog_backups "$HOME_C/skills"

for a in hunter cut prove; do
  dst="$HOME_C/agents/${a}.md"
  if [[ -f "$dst" ]]; then
    if owned_ok "agents/${a}.md" "$dst"; then
      rm -f "$dst"
      echo "[rm] ~/.cursor/agents/${a}.md"
      restore_bak "$dst"
    else
      echo "[keep] differing ~/.cursor/agents/${a}.md (not owned)"
    fi
  fi
done

rm -f "$HOME_C/kleosrules-owned.txt"

echo "[done] kleosrules uninstall complete (User Rules paste in Cursor Settings is manual)"
