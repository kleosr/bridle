#!/usr/bin/env bash
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$PACK/hooks/fleet_sync.sh" install
