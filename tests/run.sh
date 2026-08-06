#!/usr/bin/env bash
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
PASS=0

run_test() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "[pass] $name"; PASS=$((PASS + 1))
  else
    echo "[fail] $name"
    echo "  expected: $expected"
    echo "  got:      $actual"
    FAIL=$((FAIL + 1))
  fi
}

rm -rf "$PACK/state"

HANDOFF_BACKUP=""
if [[ -f "$PACK/HANDOFF.md" ]]; then
  HANDOFF_BACKUP="$(cat "$PACK/HANDOFF.md")"
fi

source "$PACK/tests/static_checks.sh"

echo ""
echo "=== Hook fixture tests ==="
source "$PACK/tests/fixtures.sh"

echo ""
echo "=== Plan-mode regression (hooks must not enforce or continue) ==="
source "$PACK/tests/plan_mode.sh"

echo ""
echo "=== Regression tests (bug fixes) ==="
source "$PACK/tests/regressions.sh"

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
rm -rf "$PACK/state"

if [[ -n "$HANDOFF_BACKUP" ]]; then
  printf '%s' "$HANDOFF_BACKUP" >"$PACK/HANDOFF.md"
fi

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
