#!/usr/bin/env bash
set -euo pipefail

PACK="$(cd "$(dirname "$0")" && pwd)/.."
PACK="$(cd "$PACK" && pwd)"
FAIL=0
PASS=0

if [[ -f "$PACK/.cursor/hooks.json" ]]; then
  rm -f "$PACK/.cursor/hooks.json"
  rm -rf "$PACK/.cursor/hooks"
fi

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

NOW_BEFORE="$(cksum <"$PACK/NOW.md")"

source "$PACK/tests/static_checks.sh"

echo ""
echo "=== Hook fixture tests ==="
source "$PACK/tests/fixtures.sh"
source "$PACK/tests/gauntlet.sh"
source "$PACK/tests/fixtures_more.sh"

echo ""
echo "=== Plan-mode regression ==="
source "$PACK/tests/plan_mode.sh"

source "$PACK/tests/audit.sh"

echo ""
echo "=== Clean tree ==="
run_test "tests did not modify NOW.md" "$NOW_BEFORE" "$(cksum <"$PACK/NOW.md")"

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
