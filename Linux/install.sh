#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PACK="$(cd "$HERE/.." && pwd)"

if [[ "${BASH_VERSINFO[0]:-0}" -lt 3 ]]; then
  echo "[fail] bash 3.2+ required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq not found — install: sudo apt-get install jq (Debian/Ubuntu) | sudo dnf install jq (Fedora) | sudo pacman -S jq (Arch)" >&2
  exit 1
fi

chmod +x "$PACK/shared/hooks"/*.sh "$PACK/shared/hooks/lib"/*.sh "$PACK/scripts"/*.sh
FORCE="${FORCE:-0}" bash "$PACK/shared/hooks/fleet_sync.sh" all

echo "[done] kleosrules installed (Linux)"
echo "Next: paste shared/rules/USER-RULES.paste.txt → Cursor Settings → User Rules, then start a NEW agent chat."
