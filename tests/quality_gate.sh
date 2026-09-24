#!/usr/bin/env bash
# Sourced by run.sh. code-architecture quality gate on a temp tree.

QG="$PACK/shared/skills/code-architecture/scripts/quality-gate.mjs"
QG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kleos-qg.XXXXXX")"
if command -v node >/dev/null 2>&1; then
  printf '%s\n' 'export function archiveModule() { return 1; }' >"$QG_DIR/archive-module.ts"
  QG_OK=0
  node "$QG" "$QG_DIR/archive-module.ts" >/dev/null 2>&1 || QG_OK=$?
  run_test "quality gate accepts a domain-named module" "0" "$QG_OK"
  printf '%s\n' 'export function go() { location.reload(); }' >"$QG_DIR/utils.ts"
  QG_BAD=0
  node "$QG" "$QG_DIR/utils.ts" >/dev/null 2>&1 || QG_BAD=$?
  run_test "quality gate rejects a generic file and a hard reload" "1" "$QG_BAD"
else
  echo "[skip] quality gate: node not on PATH"
fi
rm -rf "$QG_DIR"
