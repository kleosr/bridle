#!/usr/bin/env bash
# Local install into ~/.cursor. Windows: run from Git Bash, not PowerShell.
set -euo pipefail
exec bash "$(dirname "$0")/fleet_sync.sh" install
