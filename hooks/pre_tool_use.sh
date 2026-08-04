#!/usr/bin/env bash
# hooks/pre_tool_use.sh — thin wrapper for preToolUse event (autonomy gate).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/pre_tool_use_core.sh"
