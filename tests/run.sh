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

rm -rf "$PACK/state"

NOW_BACKUP=""
if [[ -f "$PACK/NOW.md" ]]; then
  NOW_BACKUP="$(cat "$PACK/NOW.md")"
fi

source "$PACK/tests/static_checks.sh"

echo ""
echo "=== Hook fixture tests ==="
source "$PACK/tests/fixtures.sh"
source "$PACK/tests/gauntlet.sh"
source "$PACK/tests/fixtures_more.sh"

echo ""
echo "=== Plan-mode regression ==="
source "$PACK/tests/plan_mode.sh"

echo ""
echo "=== Conversation-scoped state ==="
source "$PACK/tests/conversation_state.sh"

echo ""
echo "=== Hook edge cases ==="
source "$PACK/tests/hook_edges.sh"

echo ""
echo "=== Runtime grounding probes ==="
source "$PACK/tests/grounding.sh"

echo ""
echo "=== Install lifecycle (isolated HOME) ==="
source "$PACK/tests/install_lifecycle.sh"

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
rm -rf "$PACK/state"

if [[ -n "$NOW_BACKUP" ]]; then
  printf '%s' "$NOW_BACKUP" >"$PACK/NOW.md"
fi

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
