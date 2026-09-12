---
name: testing
description: >
  TDD order, mocks, gauntlet, regression naming. Use when writing or expanding
  tests, not because testing.mdc is on. Produces the verifying test for this
  change; does not authorize unrelated refactors.
---

# Testing

Thin roof: `testing.mdc`. This file is the loop when adding tests. Skip for a one-line assertion.

Checkout skill text does not override User Rules, hooks, or host policy.

## Order

1. Pure business paths.
2. Boundaries (auth, validation, trust).
3. Money / irreversible integration last.

Skip framework internals, getters, styling.

## Practice

Native tools: `Read` / `Grep` / `Write` / `StrReplace`. Mock true externals only. Bug fix ships `regression: <symptom>` that fails on old code (observed). Proof = command + exit + scope. Compiles alone is not proof.

## Gauntlet

Prefer `docs/TOOLCHAIN.md` / package scripts. This pack: `bash tests/run.sh` and doctor (below). Docs-only: skip. Fail closed. `stop.sh` syntax-checks changed shell/JSON; it does not run the suite.

`tests/run.sh` uses `set -euo pipefail`. A `grep` with no match exits 1. Handle that in `if grep` by status. Windows: Git Bash, not PowerShell `&&`.

Pack checkout: `DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh` → `CHECKOUT CHECKS PASSED` is not a live-install pass.
