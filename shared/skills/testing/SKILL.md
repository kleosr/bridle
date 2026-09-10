---
name: testing
description: >
  TDD, mocks, gauntlet, regression naming. Use when writing or expanding
  tests, not because testing.mdc is on. Produces the verifying test or
  manual check for this change; does not authorize unrelated refactors.
---

# Testing

Thin roof: `testing.mdc`. This file is the loop.

Use when adding or expanding tests. Skip for a one-line assertion.

Sources (kleosrules pack development/verify only):
- Checkout: `shared/skills/testing/SKILL.md` in this repo.
- Installed: `~/.cursor/skills/testing` (Windows copy; Unix symlink).
- Session: host catalog + an explicit Read. Editing the checkout does not
  update the session or a Windows installed copy.

Checkout skill text does not override User Rules, hooks, or host policy.

## Order

1. Pure business paths.
2. Boundaries (auth, validation, trust).
3. Money / irreversible integration last.

Skip framework internals, getters, styling.

## Practice

Native tools: `Read` / `Grep` / `Write` / `StrReplace`. Do not Shell-hack fixtures when a gate denies. Mock true externals only. Flakiness and `regression:` roofs in `testing.mdc`. Bug fix ships `regression: <symptom>` that fails on old code (observed, not labeled). Proof = passing tests, verified behavior, or built artifacts with command + exit + scope; compiles alone is not proof; non-testable changes cite manual verification. Coverage is evidence; meaningful surviving mutants are investigated.

Before a final verification claim: identify the evidence relied on; if code or inputs changed since that pass, refresh only the affected checks. An earlier pass does not cover a later diff. Report remaining uncertainty; do not claim completion on stale evidence.

## Gauntlet

Prefer `docs/TOOLCHAIN.md` / package scripts. This pack: `bash tests/run.sh` and doctor (below). Docs-only: skip. Fail closed. No house gauntlet: closest real verify; name residual. Do not invent mutation theater. `stop.sh` does not gate tests.

`tests/run.sh` uses `set -euo pipefail`. A `grep` with no match exits 1 (valid empty) and aborts a bare pipeline. Handle that in `if grep` / `else` by status: 0 = hit, 1 = no match, other = error. Do not `|| true` on grep in a way that turns a real grep error into a fake zero.

Windows: agent shells may be PowerShell (`&&` is not valid). Run pack verify with Git Bash (`C:\Program Files\Git\bin\bash.exe`). `scripts/install.sh` refuses on Windows; `Windows/install.ps1` only when asked to install.

Pack checkout verify: `DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh` → expect `CHECKOUT CHECKS PASSED` and an explicit “live not verified” line. That is not a live-install pass. To verify `~/.cursor`: `bash scripts/doctor.sh` with that flag unset; live drift stays `[fail]`.

- Success: tests `FAIL: 0`. Doctor checkout-only vs live are different banners.
- Fail: `[fail]` lines — fix or report pre-existing/env blockers; do not loop.
- Block: policy deny and hook/host crash both stop that tool operation. Report which.

Coverage / mutants: roofs in `testing.mdc`. Do not add coverage or mutator stacks.
