---
name: ponytail
description: >
  Native Lean ladder and split recovery. Use when writing, editing, or
  splitting any app code.
---

# Ponytail

Thin roof: `ponytail.mdc`. `stop.sh` checks churn and mass reindent only (advisory).

## Ladder

First rung that still does the job:

1. No code — config, delete, existing API.
2. Reuse — Grep this repo.
3. Stdlib.
4. Framework native.
5. Already-installed dep (new package: one chat line why lower rungs fail).
6. One clear line.
7. Minimum diff per `ponytail.mdc` thresholds.

## Quality

Quality floors in `ponytail.mdc`. Jargon: `bans.txt` beside this file (fail-open if missing). Behavior change: test when the testing skill applies.

## Split

Read → plan → Write new modules → StrReplace original to imports → Grep callers. Never Shell sed/echo>/tee.

`domains/` only if the project uses DDD: [domains-ddd.md](domains-ddd.md). `frontend/` + `backend/` only if the project separates them: [fe-be-layout.md](fe-be-layout.md).

## Floors

Trust, authz, data-loss, a11y, explicit asks. Cyclo: `complexity.mdc`. Style off only if the user says stop ponytail; safety denials stay.
