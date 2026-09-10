#!/usr/bin/env bash
# Pack verify: syntax, hook fixtures, gate edges, install lifecycle.
# set -euo pipefail: handle grep-no-match by status (0 hit, 1 no match),
# never by masking real errors with `|| true`.
set -euo pipefail

REAL_PACK="$(cd "$(dirname "$0")" && pwd)/.."
REAL_PACK="$(cd "$REAL_PACK" && pwd)"
PACK="$(mktemp -d "${TMPDIR:-/tmp}/kleos-pack.XXXXXX")"
cp -a "$REAL_PACK/." "$PACK/"
FAIL=0
PASS=0

# Portability: some Windows jq builds emit CRLF; tests compare jq scalars.
if ! declare -F jq >/dev/null 2>&1; then
  jq() { command jq "$@" | tr -d '\r'; }
fi

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
echo "=== Hook fixtures ==="
source "$PACK/tests/fixtures.sh"

echo ""
echo "=== Gate edges (false positives / bypasses) ==="
source "$PACK/tests/gate_edges.sh"

echo ""
echo "=== Stop gate ==="
source "$PACK/tests/stop_edges.sh"

echo ""
echo "=== Install lifecycle (isolated HOME) ==="
source "$PACK/tests/install_lifecycle.sh"

echo ""
echo "=== Grounding (shapes, not prose) ==="
source "$PACK/tests/grounding.sh"

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
