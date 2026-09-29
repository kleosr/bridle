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

# Portability: this also fails before the copied pack's first assertion.
source "$REAL_PACK/shared/gate/lib/common.sh"
require_jq

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

# TESTS=fixtures,harness runs only those fixtures (scoped evidence for one
# feature). Unset runs the whole gauntlet. static_checks always runs: syntax
# is layer 1 and every fixture depends on it.
selected() {
  [[ -z "${TESTS:-}" ]] && return 0
  case ",${TESTS}," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

source "$PACK/tests/pack/static_checks.sh"

if selected fixtures; then
  echo ""
  echo "=== Hook fixtures ==="
  source "$PACK/tests/gate/fixtures.sh"
fi

if selected gate_edges; then
  echo ""
  echo "=== Gate edges (false positives / bypasses) ==="
  source "$PACK/tests/gate/gate_edges.sh"
fi

if selected overlay_edges; then
  echo ""
  echo "=== Overlay edges (BOM stdin, retired mdc, shim merge) ==="
  source "$PACK/tests/hosts/overlay_edges.sh"
fi

if selected sql_scope; then
  echo ""
  echo "=== SQL scope (program-scoped destructive SQL) ==="
  if bash "$PACK/tests/gate/sql_scope.sh"; then
    run_test "sql_scope: all program-scope checks pass" "pass" "pass"
  else
    run_test "sql_scope: all program-scope checks pass" "pass" "fail"
  fi
fi

if selected install_lifecycle; then
  echo ""
  echo "=== Install lifecycle (isolated HOME) ==="
  source "$PACK/tests/hosts/install_lifecycle.sh"
fi

if selected claude_stop; then
  echo ""
  echo "=== Claude Stop hook (synthetic transcripts, isolated HOME) ==="
  source "$PACK/tests/hosts/claude_stop.sh"
fi

if selected claude_gates; then
  echo ""
  echo "=== Claude gates (BRIDLE_HOST=claude, isolated HOME) ==="
  source "$PACK/tests/hosts/claude_gates.sh"
fi

if selected opencode_port; then
  echo ""
  echo "=== opencode port (isolated HOME) ==="
  source "$PACK/tests/hosts/opencode_port.sh"
fi

if selected scope_eval; then
  echo ""
  echo "=== Scope eval scorer (golden overlays, no agent) ==="
  source "$PACK/tests/pack/scope_eval.sh"
fi

if selected quality_gate; then
  echo ""
  echo "=== code-architecture quality gate ==="
  source "$PACK/tests/pack/quality_gate.sh"
fi

if selected grounding; then
  echo ""
  echo "=== Grounding (shapes, not prose) ==="
  source "$PACK/tests/pack/grounding.sh"
fi

if selected harness; then
  echo ""
  echo "=== Harness contracts (features, handoff, evals) ==="
  source "$PACK/tests/pack/harness.sh"
fi

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
