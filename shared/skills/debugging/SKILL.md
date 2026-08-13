---
name: debugging
description: >-
  Debugs difficult, intermittent, cross-layer, or regression bugs
  evidence before fixes. Use when the cause is unknown, normal debugging
  stalled, or the user asks to hunt, diagnose, or root-cause a bug.
---

# Bug hunt

No thin `.mdc`. This skill is the debugging roof.

Prove the cause; do not change code to generate hypotheses.

## Mode

- Diagnose/assess → findings only.
- Fix requested → investigate first, then apply the smallest proven fix.

## Workflow

1. State the exact symptom, expected behavior, scope, and known-good baseline.
2. Reproduce with the smallest deterministic case. Cannot reproduce → report
   the missing signal and stop.
3. Read the complete error, logs, stack, inputs, and relevant state.
4. Classify the likely boundary: logic, data, state, concurrency, cache,
   configuration, contract, environment, or integration.
5. Trace backward from the first wrong observable value; compare failing and
   working paths.
6. Write one falsifiable hypothesis and gather evidence for or against it.
7. Inspect callers, contracts, and recent history when evidence points there.
8. Prove the root cause before editing. After three misses, send STUCK with
   evidence and ask for the missing information.
9. If authorized, fix one cause, add a regression test, and rerun the original
   reproduction plus affected TOOLCHAIN checks.

## Guardrails

- No catch/sleep/retry, mock, assertion, or test weakening to hide failure.
- No simultaneous fixes for competing hypotheses.
- Cross-boundary symptoms use session-handoff; communication failures may
  use session-handoff.
- Preserve logs/artifacts needed to explain the result; never expose secrets.

## Report

Symptom → proven cause → evidence → changed or recommended fix → regression
and original-repro results. Label anything unverified.
