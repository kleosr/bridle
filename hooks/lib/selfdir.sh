#!/usr/bin/env bash
# Directory of a script path, builtins only.
# External dirname forks. On MSYS a dead fork (cygheap copy failed) left `cd`
# with an empty argument, the hook exited under set -e before any JSON, and
# the host fail-closed a legitimate call.

kleos_abs_dir() {
  local s="${1//\\//}" d
  d="${s%/*}"
  if [[ "$d" == "$s" || -z "$d" ]]; then
    d="."
  fi
  case "$d" in
    /*|[A-Za-z]:/*) printf '%s' "$d" ;;
    *) printf '%s' "$(pwd)/$d" ;;
  esac
}
