#!/usr/bin/env bash
# scripts/install.sh — install kleosrules hooks + rules into Cursor.
# Delegates to fleet_sync.sh which is the canonical installer.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$PACK/hooks/fleet_sync.sh" install
