#!/usr/bin/env bash
# hooks/stop_gate.sh — thin wrapper for stop event.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/stop_gate_core.sh"
