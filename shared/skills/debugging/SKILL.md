---
name: debugging
description: >
  Evidence-first debug for unknown or intermittent bugs. Use when the cause
  is unknown or the user asks to diagnose.
---

# Bug hunt

No thin `.mdc`. Prove the cause. Do not change code to generate hypotheses.

Diagnose → findings only. Fix requested → investigate, then the smallest proven fix.

1. Symptom, expected, scope, known-good.
2. Smallest deterministic repro. Cannot reproduce → stop and say what is missing.
3. Read the full error, logs, stack, inputs, state.
4. Classify: logic, data, state, concurrency, cache, config, contract, env, integration.
5. Trace backward from the first wrong value.
6. One falsifiable hypothesis. Evidence for or against.
7. Callers / contracts / history when evidence points there.
8. Prove root cause before edit. Three misses → STUCK + evidence.
9. If asked: one cause, regression test, rerun repro + TOOLCHAIN.

No catch/sleep/retry/mock/assert weakening. No two competing fixes at once. Cross-boundary: `NOW.md`. Never expose secrets.

Report: symptom → cause → evidence → fix → repro results. Label unverified.
