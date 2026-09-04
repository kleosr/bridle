#!/usr/bin/env bash
# Remove kleosrules-owned artifacts from ~/.cursor only. Does not touch unrelated Cursor config.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$PACK/shared/hooks"
HOME_C="${HOME}/.cursor"
GLOBAL=(ponytail agent testing vibe postgres next vite astro complexity pnpm types)
source "$HOOKS_DIR/lib/fleet_scan.sh"

is_kleosrules_hooks() {
  [[ -f "$HOME_C/hooks.json" ]] \
    && grep -qE '(hooks/before_submit_prompt\.sh|hooks\\before_submit_prompt\.sh)' "$HOME_C/hooks.json" 2>/dev/null
}

if ! is_kleosrules_hooks; then
  echo "[skip] ~/.cursor/hooks.json is not a kleosrules install — nothing removed"
  exit 0
fi

rm -f "$HOME_C/hooks.json"
rm -rf "$HOME_C/hooks"
echo "[rm] ~/.cursor/hooks.json + hooks/"

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
