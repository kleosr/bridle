#!/usr/bin/env bash
# Schema-validated session handoff. Continuity evidence, not authority.
# Default path is gitignored: state/handoff.json
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=shared/hooks/lib/common.sh
source "$PACK/shared/hooks/lib/common.sh"
# shellcheck source=shared/hooks/lib/feature_gate.sh
source "$PACK/shared/hooks/lib/feature_gate.sh"
require_jq
ledger_paths "$(ledger_root)"
FILE="${HANDOFF_FILE:-$LEDGER_HANDOFF}"
CMD="${1:-}"

usage() {
  echo "usage: bash scripts/handoff.sh {check|print|write}" >&2
  echo "file: this pack -> state/handoff.json; any other repo -> <root>/.cursor/bridle/handoff.json (HANDOFF_FILE override)." >&2
  echo "write reads JSON on stdin." >&2
  exit 2
}

valid_shape() {
  local f="$1"
  jq empty "$f" >/dev/null 2>&1 || return 1
  jq -e '.version == 1
    and (.task | type == "string" and length > 0)
    and ((.investigated // []) | type == "array" and all(.[]; type == "string"))
    and ((.changed // []) | type == "array" and all(.[]; type == "string"))
    and ((.failed // []) | type == "array" and all(.[]; type == "string"))
    and (.nextAction | type == "string" and length > 0)
    and (.remaining | type == "array" and all(.[]; type == "string"))
    and ((.decisions // []) | type == "array" and all(.[]; type == "string"))
    and (.verified | type == "object")
    and (.verified.command | type == "string" and length > 0)
    and (.verified.exit | type == "number" and floor == .)
    and ((.activeFeature | type == "string") or .activeFeature == null)' "$f" >/dev/null
}

cmd_check() {
  if [[ ! -f "$FILE" ]]; then
    echo "handoff absent (ok)"
    return 0
  fi
  valid_shape "$FILE" || { echo "invalid handoff: $FILE" >&2; exit 1; }
  echo "handoff ok"
}

cmd_print() {
  if [[ ! -f "$FILE" ]]; then
    echo "handoff absent"
    return 0
  fi
  cat "$FILE"
}

cmd_write() {
  local tmp dir
  dir="$(dirname "$FILE")"
  mkdir -p "$dir"
  tmp="$(mktemp "${TMPDIR:-/tmp}/kleos-handoff.XXXXXX")"
  cat >"$tmp"
  if ! valid_shape "$tmp"; then
    rm -f "$tmp"
    echo "handoff JSON failed schema (version, task, verified.command, verified.exit, remaining, nextAction)" >&2
    exit 1
  fi
  mv "$tmp" "$FILE"
  echo "wrote $FILE"
}

case "$CMD" in
  check) cmd_check ;;
  print) cmd_print ;;
  write) cmd_write ;;
  *) usage ;;
esac
