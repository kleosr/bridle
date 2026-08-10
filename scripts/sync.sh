#!/usr/bin/env bash
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
bash "$PACK/MacOS/hooks/fleet_sync.sh" sync
bash "$PACK/MacOS/hooks/fleet_sync.sh" verify
