#!/usr/bin/env bash
set -euo pipefail

REAL_PACK="$(cd "$(dirname "$0")" && pwd)/.."
REAL_PACK="$(cd "$REAL_PACK" && pwd)"
PACK="$(mktemp -d "${TMPDIR:-/tmp}/kleos-pack.XXXXXX")"
cp -a "$REAL_PACK/." "$PACK/"
FAIL=0
PASS=0

cleanup_pack() {
  cd "${TMPDIR:-/tmp}" 2>/dev/null || true
  rm -rf "$PACK"
}
trap cleanup_pack EXIT
cd "$PACK"

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

rm -rf "$PACK/state" "$PACK/.cursor/hooks.json" "$PACK/.cursor/hooks"

source "$PACK/tests/static_checks.sh"

echo ""
echo "=== Hook fixture tests ==="
source "$PACK/tests/fixtures.sh"
source "$PACK/tests/gauntlet.sh"
source "$PACK/tests/fixtures_more.sh"

echo ""
echo "=== Gate edges (false positives / bypasses) ==="
source "$PACK/tests/gate_edges.sh"

echo ""
echo "=== Plan-mode regression ==="
source "$PACK/tests/plan_mode.sh"

echo ""
echo "=== Hook edge cases ==="
source "$PACK/tests/hook_edges.sh"

echo ""
echo "=== Runtime grounding probes ==="
source "$PACK/tests/grounding.sh"

echo ""
echo "=== Eval corpus (control + prose presence + manual rubric) ==="
source "$PACK/tests/eval_corpus.sh"

echo ""
echo "=== Install lifecycle (isolated HOME) ==="
source "$PACK/tests/install_lifecycle.sh"

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
