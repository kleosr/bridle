---
name: ponytail
description: >
  Lazy senior / Native Lean decision trees: no code → reuse → stdlib → platform →
  installed dep → one line → minimum. Deny recovery splits. Edge-case architecture
  criteria. Use when writing app code or when thin ponytail.mdc points here.
---

# Ponytail (fat skill)

Thin roof: `project-rules/ponytail.mdc` (ladder + skill pointer + deny one-liner).
This file = decision trees and edge cases.

## Ladder detail
Stop at first rung that holds after reading the ask + touched code:
1. NO CODE — config, delete, existing API.
2. Reuse — Grep codebase; Obsidian MCP for prior decisions.
3. Stdlib of the language.
4. Framework native (React/Node/platform).
5. Already-installed dependency (no new package without Soft Rule why).
6. One clear line.
7. Minimum — shortest correct private-native diff. Prefer files under soft 80 LOC;
   hard roof `hooks/lean_gate.sh` denies writes/edits whose projected post-edit size exceeds 700 LOC.

Soft Rule: skipping a rung needs one chat line naming why lower rungs fail.

## Refactor decision tree
When adding behavior to a hot file:
- If file approaches 700 projected LOC: extract first (Deny Recovery), then add. The gate checks the projected post-edit size, so removing code to split always passes.
- Third real repetition → extract; before that, duplicate is cheaper.
- Shared change: Grep callers; private-match siblings; blast-radius in chat.
- Prefer deletion over wrappers. No monorepo/Nx/Clean Architecture theater.

## Deny Recovery (full)
On lean_gate deny:
1. Read the blocked file.
2. Plan split (functions/classes → new modules under vernacular paths).
3. Write new small files under roof.
4. StrReplace original with imports.
5. Grep old import paths; StrReplace cascade.
6. Retry original diff. Never Shell sed/echo>/tee bypass.

## Hard floors
- No prose comments in app code (machine directives only for green build).
- Never lazy about trust boundaries, data-loss errors, security, a11y, explicit asks.
- Off only: user says stop ponytail / stop lean-code / normal mode.

## Alias
`lean-code` skill/rule = this mode.
