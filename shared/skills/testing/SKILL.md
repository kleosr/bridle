---
name: testing
description: >
  TDD, mocks, gauntlet, regression naming. Use when writing or expanding
  tests, not because testing.mdc is on.
---

# Testing

Thin roof: `testing.mdc`. This file is the loop.

## Order

1. Pure business paths.
2. Boundaries (auth, validation, trust).
3. Money / irreversible integration last.

Skip framework internals, getters, styling.

## Practice

Native tools: `Read` / `Grep` / `Write` / `StrReplace`. Do not Shell-hack fixtures when a gate denies. Mock true externals only. Flakiness and `regression:` roofs in `testing.mdc`. Bug fix ships `regression: <symptom>` that fails on old code. Proof = passing tests, verified behavior, or built artifacts; compiles alone is not proof; non-testable changes cite manual verification.

## Gauntlet

Prefer `docs/TOOLCHAIN.md` / package scripts. Hooks/scripts/tests → `bash tests/run.sh` and `scripts/doctor.sh`. Docs-only: skip. Fail closed. No house gauntlet: closest real verify; name residual. Do not invent mutation theater. `stop.sh` does not gate tests.

Coverage / mutants: roofs in `testing.mdc`. Do not add coverage or mutator stacks.
