---
name: complexity
description: >
  Wire and satisfy cyclomatic complexity lint. Detect the repo's existing
  linter, set or keep a cap (default 10), extract until green, never disable
  the rule. Use when complexity.mdc globs match, lint reports C901/complexity,
  or the user asks for simpler / less nested code.
---

# Complexity (fat skill)

Thin roof: `shared/rules/complexity.mdc`. This file = how to wire the number and recover when red.

## Cap
Repo config wins. Else **10**.
Do not switch to Sonar cognitive complexity unless this repo already uses it.

## Detect (Grep, then one tool)
1. Grep `complexity`, `C901`, `mccabe`, `gocyclo`, `cyclo` in eslint/ruff/clippy/pyproject/Makefile/CI.
2. If a cap exists, that number is law. Do not raise it.
3. If missing and eslint or ruff is already installed: add the rule to that config. Do not add a new linter stack.
4. If no linter exists: still write as if cap 10. Cite that TOOLCHAIN has no complexity job. Do not invent eslint for a repo that has none.

## TS/JS
Existing eslint: `"complexity": ["error", 10]` (or the repo's number).
Run the repo's lint on the files you touched (`pnpm exec eslint path`, not a global npx stack).

## Python
Existing ruff: `C901` with `max-complexity = 10` (or the repo's number).
Pylint `R1260` only if pylint is already the house linter.

## Go / Rust
gocyclo or clippy only if already in TOOLCHAIN. Same cap.

## Red
Extract a function. Early return. Table/map instead of `else if` chains.
Never `eslint-disable` complexity, `# noqa: C901`, `--ignore C901`, or clippy allow-wrap.
`before_shell.sh` denies those bypasses.

## Done
Cite the lint command and green output. Same standard as testing.mdc.
