#!/usr/bin/env bash
# Local install into ~/.cursor. Windows: run from Git Bash, not PowerShell.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$PACK/shared/hooks/fleet_sync.sh" install
