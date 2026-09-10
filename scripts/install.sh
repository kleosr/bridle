#!/usr/bin/env bash
# Local install into ~/.cursor. Windows: run from Git Bash, not PowerShell.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
case "$(uname -s 2>/dev/null || true)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "[fail] On Windows use Git Bash (not PowerShell): bash scripts/install.sh" >&2
    exit 1
    ;;
esac
exec bash "$PACK/shared/hooks/fleet_sync.sh" install
