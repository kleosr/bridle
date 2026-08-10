#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PACK="$(cd "$HERE/.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq not found — install it first: brew install jq" >&2
  exit 1
fi

chmod +x "$HERE/hooks"/*.sh "$HERE/hooks/lib"/*.sh "$PACK/scripts"/*.sh
FORCE="${FORCE:-0}" bash "$HERE/hooks/fleet_sync.sh" all

echo "[done] kleosrules installed (macOS)"
echo "Next: paste rules/USER-RULES.paste.txt → Cursor Settings → User Rules, then start a NEW agent chat."
