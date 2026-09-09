#!/usr/bin/env bash

shell_is_fleet_sync() {
  case "$1" in
    *$'\n'*|*$'\r'*|*';'*|*'|'*|*'&'*|*'$'*|*'`'*|*'#'*|*'('*|*')'*) return 1 ;;
  esac
  printf '%s' "$1" | grep -qE '^[[:space:]]*(FORCE=1[[:space:]]+)?bash[[:space:]]+scripts/install\.sh[[:space:]]*$' && return 0
  printf '%s\n' "$1" | grep -qE '^[[:space:]]*(FORCE=1[[:space:]]+)?bash[[:space:]]+shared/hooks/fleet_sync\.sh([[:space:]]+(install|verify|all|project-hooks))?[[:space:]]*$'
}
