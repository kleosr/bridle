#!/usr/bin/env bash

shell_is_fleet_sync() {
  printf '%s' "$1" | grep -qE '^[[:space:]]*(FORCE=1[[:space:]]+)?bash[[:space:]]+(shared/hooks/fleet_sync\.sh|scripts/install\.sh)([[:space:]]+[a-z|-]+)*[[:space:]]*$'
}
