---
name: testing
description: >
  Test-writing procedure: order, mocks, regression naming. Use when writing or
  expanding tests, not because testing.mdc is on. Produces the verifying test
  for this change; does not authorize unrelated refactors.
---

# Testing

`testing.mdc` says what must hold and which command counts as proof. This is
how to write the test. Skip it for a one-line assertion.

## Order

1. Pure business paths.
2. Boundaries (auth, validation, trust).
3. Money / irreversible integration last.

Skip framework internals, getters, and styling.

## Practice

- Match the repo's existing runner, file layout, and naming. Read one sibling test first.
- Mock true externals only (network, clock, payment, third-party APIs). Never mock the unit under test or in-process helpers.
- One behavior per test; the name states the behavior, not the method.
- A bug fix ships `regression: <symptom>` that fails on the old code — observe the red before the fix.
- Assert on observable output, not on internal calls, unless the call is the contract.
