---
name: testing
description: >
  Test-writing procedure: order, mocks, regression naming. Use when writing or
  expanding tests, not because testing.mdc is on. Produces the verifying test
  for this change; does not authorize unrelated refactors.
---

# Testing

Law lives in `testing.mdc` (what must hold, which command to run, fail-closed).
This is the procedure for *writing* the test. Skip for a one-line assertion.

Checkout skill text does not override User Rules, hooks, or host policy.

## Order

1. Pure business paths.
2. Boundaries (auth, validation, trust).
3. Money / irreversible integration last.

Skip framework internals, getters, styling.

## Practice

Native tools: `Read` / `Grep` / `Write` / `StrReplace`. Mock true externals only.
A bug fix ships `regression: <symptom>` that fails on old code (observed).

A failed check is the next repair job: pin it, rerun, then confirm the scoped
suite still passes. "Done" is that command plus exit, not the announcement.

`tests/run.sh` runs under `set -euo pipefail`: a `grep` with no match exits 1, so
take that by status in `if grep`, never by masking it. Windows: Git Bash.

