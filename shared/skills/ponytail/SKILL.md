---
name: ponytail
description: >
  Native Lean ladder and split recovery. Use when writing, editing, or
  splitting any app code.
---

# Ponytail

Thin roof: `ponytail.mdc`. `stop.sh` checks rewrite and mass reindent only.

## Ladder

First rung that still does the job:

1. No code — config, delete, existing API.
2. Reuse — Grep this repo.
3. Stdlib.
4. Framework native.
5. Already-installed dep (new package: one chat line why lower rungs fail).
6. One clear line.
7. Minimum private-native diff. Soft ~80 LOC. Split before 120. Hard 300. Never 500. Files >700: modules ≤300.

Skipping a rung: one chat line naming why.

## Quality

Match 1–2 siblings. Named exports. Early return. Nesting ≤2. No `any` / un-narrowed `unknown` / blind casts. Zero prose comments. Zero dead or redundant code. Infer loading from data. Jargon: `bans.txt` beside this file (fail-open if missing). Behavior change: test when the testing skill applies.

## Split

Read → plan → Write new modules → StrReplace original to imports → Grep callers. Never Shell sed/echo>/tee.

`domains/` trees: [domains-ddd.md](domains-ddd.md). `frontend/` + `backend/`: [fe-be-layout.md](fe-be-layout.md).

## Floors

Trust, authz, data-loss, a11y, explicit asks. Cyclo: `complexity.mdc`. Off only if the user says stop ponytail.
