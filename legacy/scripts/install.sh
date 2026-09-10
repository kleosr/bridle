#!/usr/bin/env bash
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "[fail] Windows: powershell -File Windows/install.ps1" >&2
    exit 1
    ;;
esac
exec bash "$PACK/shared/hooks/fleet_sync.sh" install
