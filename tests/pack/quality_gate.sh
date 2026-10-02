#!/usr/bin/env bash
# Sourced by run.sh. code-architecture quality gate on a temp tree.

QG="$PACK/skills/code-architecture/scripts/quality-gate.mjs"
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

  QG_REPO="$QG_DIR/repo"
  mkdir -p "$QG_REPO"
  printf '%s\n' 'export function legacyTotal(rows: any) { console.log(rows); return 1; }' >"$QG_REPO/helpers.ts"
  git -C "$QG_REPO" init -q
  git -C "$QG_REPO" add helpers.ts
  git -C "$QG_REPO" -c user.name=t -c user.email=t@t commit -qm legacy
  printf '%s\n' 'export function archiveModule() { return 2; }' >>"$QG_REPO/helpers.ts"
  QG_LEGACY=0
  (cd "$QG_REPO" && node "$QG" >/dev/null 2>&1) || QG_LEGACY=$?
  run_test "regression: quality gate ignores pre-existing findings outside the diff" "0" "$QG_LEGACY"
  printf '%s\n' 'export const moduleCount = 3 as any;' >>"$QG_REPO/helpers.ts"
  QG_ADDED=0
  (cd "$QG_REPO" && node "$QG" >/dev/null 2>&1) || QG_ADDED=$?
  run_test "quality gate still rejects an error on a line the diff added" "1" "$QG_ADDED"

  printf '%s\n' 'export function ok() { return 1; }' '// ==========' 'export function bad() { return 2; }' >"$QG_DIR/banner.ts"
  QG_BAN=0
  node "$QG" "$QG_DIR/banner.ts" >/dev/null 2>&1 || QG_BAN=$?
  run_test "quality gate rejects a comment banner" "1" "$QG_BAN"

  printf '%s\n' 'export function ok() { return 1; }' '// added for the sidebar' 'export function bad() { return 2; }' >"$QG_DIR/history.ts"
  QG_HIST=0
  node "$QG" "$QG_DIR/history.ts" >/dev/null 2>&1 || QG_HIST=$?
  run_test "quality gate rejects a change-history comment" "1" "$QG_HIST"

  printf '%s\n' '// TODO fix later' 'export function ok() { return 1; }' >"$QG_DIR/todo.ts"
  QG_TODO=0
  node "$QG" "$QG_DIR/todo.ts" >/dev/null 2>&1 || QG_TODO=$?
  run_test "quality gate rejects an ownerless TODO" "1" "$QG_TODO"

  DENSITY_FILE="$QG_DIR/dense.ts"
  {
    echo 'export function dense() {'
    for _ in $(seq 1 9); do echo '  return 1;'; done
    for _ in $(seq 1 2); do echo '  // noise'; done
    echo '}'
  } >"$DENSITY_FILE"
  QG_DEN=0
  node "$QG" "$DENSITY_FILE" >/dev/null 2>&1 || QG_DEN=$?
  run_test "quality gate rejects high comment density on added lines" "1" "$QG_DEN"
else
  echo "[skip] quality gate: node not on PATH"
fi
rm -rf "$QG_DIR"
