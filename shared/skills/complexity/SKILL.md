---
name: complexity
description: >
  Satisfy cyclomatic lint; never disable. Use when lint is red or the user
  asks for simpler code.
---

# Complexity

Thin roof: `complexity.mdc`. Nesting ≤2 is not a substitute.

## Cap

Caps live in `complexity.mdc`. This skill is detection + reduction only.

## Detect

1. Grep `complexity`, `C901`, `mccabe`, `gocyclo`, `cyclo`, `cognitive` in eslint/ruff/clippy/biome/`pyproject.toml`/Makefile/CI.
2. Existing cap is law.
3. If missing and eslint, ruff, or biome already runs: add the rule there. Do not add a linter stack.
4. No linter: write as cap 10. Cite that TOOLCHAIN has no complexity job.

TS/JS: repo `complexity` option (legacy or flat). Run **repo** lint on touched files (`pnpm exec eslint path`). Python: ruff `C901`. Go/Rust: gocyclo/clippy only if already in TOOLCHAIN.

## Red

Early return. Flatten `if`. `else if` → table. One-job extracts. Nested ternary → `if` or lookup. Never disable complexity lint — `before_shell.sh` denies it.

Done: per `complexity.mdc` (green when a job exists; else report unmeasured).
