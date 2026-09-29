#!/usr/bin/env bash
# Sourced by run.sh. Syntax, shellcheck, JSON validity.

echo "=== Syntax checks ==="
for f in "$PACK"/shared/gate/*.sh "$PACK"/shared/gate/lib/*.sh "$PACK"/shared/hosts/*/*.sh "$PACK"/shared/hosts/cursor/lib/*.sh "$PACK"/scripts/*.sh "$PACK"/scripts/eval/*.sh; do
  if bash -n "$f" 2>/dev/null; then
    echo "[pass] syntax: ${f#$PACK/}"; PASS=$((PASS + 1))
  else
    echo "[fail] syntax: ${f#$PACK/}"; FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== shellcheck (if available) ==="
if command -v shellcheck >/dev/null 2>&1; then
  for f in "$PACK"/shared/gate/*.sh "$PACK"/shared/gate/lib/*.sh "$PACK"/shared/hosts/*/*.sh "$PACK"/shared/hosts/cursor/lib/*.sh "$PACK"/scripts/*.sh "$PACK"/scripts/eval/*.sh; do
    if shellcheck -S warning "$f" 2>/dev/null; then
      echo "[pass] shellcheck: ${f#$PACK/}"; PASS=$((PASS + 1))
    else
      echo "[warn] shellcheck: ${f#$PACK/} (issues found)"
    fi
  done
else
  echo "[skip] shellcheck not installed"
fi

echo ""
echo "=== JSON validity ==="
for j in "$PACK"/shared/hosts/cursor/hooks.json "$PACK"/shared/hosts/cursor/hooks.cloud.json \
  "$PACK"/shared/catalog/manifest.json "$PACK"/shared/config/harness.json \
  "$PACK"/shared/config/features.json "$PACK"/package.json \
  "$PACK"/evals/tasks.json; do
  [[ -f "$j" ]] || continue
  if jq empty "$j" 2>/dev/null; then
    echo "[pass] valid JSON: ${j#$PACK/}"; PASS=$((PASS + 1))
  else
    echo "[fail] invalid JSON: ${j#$PACK/}"; FAIL=$((FAIL + 1))
  fi
done
