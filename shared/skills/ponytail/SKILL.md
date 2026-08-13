---
name: ponytail
description: >
  Lazy senior / Native Lean decision trees: no code → reuse → stdlib → platform →
  installed dep → one line → minimum. Split recovery. Edge-case architecture
  criteria. Use when writing app code or when thin ponytail.mdc points here.
---

# Ponytail (fat skill)

Thin roof: `shared/rules/ponytail.mdc` (ladder, tools, split pointer).
This file = decision trees and edge cases. No registered lean hook.

## Ladder detail
Stop at first rung that holds after reading the ask + touched code:
1. NO CODE — config, delete, existing API.
2. Reuse — Grep codebase.
3. Stdlib of the language.
4. Framework native (React/Node/platform).
5. Already-installed dependency (no new package without Soft Rule why).
6. One clear line.
7. Minimum — shortest correct private-native diff. Prefer files under soft ~80 LOC.
   Split before 120. Do not grow past 300. Files >700 LOC: rewrite into subatomic
   modules ≤300 (Write new, StrReplace original + callers to imports).
   Zero prose comments. Subatomic = one job per file, small surface, no god-files.

Soft Rule: skipping a rung needs one chat line naming why lower rungs fail.

## Refactor decision tree
When adding behavior to a hot file:
- If file approaches 300 LOC: extract first, then add.
- If file is already >700 LOC: rewrite now — extract subatomic modules; reducing
  edits allowed, growth not. Update imports on original and callers.
- Third real repetition → extract; before that, duplicate is cheaper.
- Shared change: Grep callers; private-match siblings; blast-radius in chat.
- Prefer deletion over wrappers. No monorepo/Nx/Clean Architecture theater.

## Split recovery
When a file is over roof:
1. `Read` the file.
2. Plan split (functions/classes → new modules under vernacular paths).
3. `Write` new small files under roof.
4. `Write` original with imports (overwrite reduced source).
5. `Grep` old import paths; `Write` cascade.
6. Retry original diff. Never Shell sed/echo>/tee — `before_shell.sh` denies it.

## Hard floors
- Zero prose comments in app code (machine directives only).
- Never lazy about trust boundaries, data-loss errors, security, a11y, explicit asks.
- Cursor tools: Write/Shell/Read/Grep/Delete/Task.
- Off only: user says stop ponytail / normal mode.
