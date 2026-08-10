---
name: testing
description: >
  Test writing workflows: TDD order, mocks, house gauntlet, regression naming.
  Use when writing/editing tests or when testing.mdc globs match. Thin rule =
  roofs; this skill = procedure.
---

# Testing (fat skill)

Thin roof: `rules/testing.mdc`. This file = how to run the loop.

## Order (TDD-ish)
1. Business logic pure paths.
2. Boundaries (auth, validation, trust edges).
3. Money-path / irreversible integration last.
Skip: framework internals, getters, styling.

## Native tools
Use Cursor `Read` / `Grep` / `Write` / `StrReplace` for test files.
Do not Shell-hack fixtures with sed/echo redirects when a gate denies.

## Mocks
Mock true externals only (network, clock, FS outside fixture).
Prefer hand oracles for seam asserts. Flaky = broken: fix or delete same day.

## Regression
Bug fix ships a test named or described `regression: <symptom>` that fails on old code.

## House gauntlet (Martin)
1. Prefer `docs/TOOLCHAIN.md` / package test scripts already wired.
2. ACT NOW — run them yourself; cite green evidence before Done.
3. Fail closed on red.
4. No house gauntlet: run closest real verify; name residual; never ask accept-no-gauntlet-risk.
5. Do not invent mutation theater or Clean Architecture test trees.

## Coverage
Smoke detector, not a trophy. Prefer one hostile path over metric theater.
