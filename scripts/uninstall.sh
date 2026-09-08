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

for name in "${GLOBAL[@]}"; do
  if [[ -f "$HOME_C/rules/${name}.mdc" ]]; then
    rm -f "$HOME_C/rules/${name}.mdc"
    echo "[rm] ~/.cursor/rules/${name}.mdc"
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

for a in hunter cut prove; do
  if [[ -f "$HOME_C/agents/${a}.md" ]]; then
    rm -f "$HOME_C/agents/${a}.md"
    echo "[rm] ~/.cursor/agents/${a}.md"
  fi
done

echo "[done] kleosrules uninstall complete (User Rules paste in Cursor Settings is manual)"
