#!/usr/bin/env bash
# scripts/sync.sh — sync kleosrules into all fleet repos + verify.
# Delegates to fleet_sync.sh sync + verify.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
bash "$PACK/hooks/fleet_sync.sh" sync
bash "$PACK/hooks/fleet_sync.sh" verify
