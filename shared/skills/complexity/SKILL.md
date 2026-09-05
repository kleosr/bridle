---
name: complexity
description: >
  Satisfy cyclomatic lint; never disable. Use when lint is red or the user
  asks for simpler code.
---

# Complexity

Thin roof: `shared/rules/complexity.mdc`. The lint number is law. Nesting ≤2 in ponytail is not a substitute.

## Cap

Repo config wins. Else **10**. Never above **22** — extract; do not raise a cap toward 22. Do not raise a cap that already exists below 22. Do not switch to Sonar cognitive complexity unless this repo already uses it; if it does, that cap or **22**, whichever is tighter.

Cognitive / Halstead difficulty / CRAP: only if this repo already prints those numbers. Caps: cognitive **22**, Halstead difficulty **80**, CRAP **25**. Do not add those tools.

## Detect (Grep, then one tool)

1. Grep `complexity`, `C901`, `mccabe`, `gocyclo`, `cyclo`, `cognitive` in eslint/ruff/clippy/biome/`pyproject.toml`/Makefile/CI.
2. If a cap exists, that number is law.
3. If missing and eslint, ruff, or biome is already installed: add the rule to **that** config. Do not add a new linter stack.
4. If no linter exists: still write as if cap 10. Cite that TOOLCHAIN has no complexity job. Do not invent eslint for a repo that has none.

## TS/JS

Legacy `.eslintrc*`: `"complexity": ["error", 10]` (or the repo's number).

Flat `eslint.config.*`: keep the repo's existing `complexity` option; if absent and eslint already runs, add it next to the other rules — same number.

Run the **repo** lint on files you touched (`pnpm exec eslint path`, `pnpm exec biome check path`). Not a global npx stack.

## Python / Go / Rust

Ruff: `C901` with `max-complexity = 10` (or the repo's number). Pylint `R1260` only if pylint is already the house linter. gocyclo or clippy only if already in TOOLCHAIN.

## Red — extract until green

Do this, in order:

1. Early return. Flatten `if`.
2. Replace `else if` chains with a map/table.
3. Pull a branch into a named function that does one job.
4. Nested ternary → `if` or a lookup.

Never `eslint-disable` complexity, `# noqa: C901`, `--ignore C901`, or clippy allow-wrap. `before_shell.sh` denies those bypasses.

```ts
// BAD — one function owns every branch
export function route(cmd: string, admin: boolean): string {
  if (cmd === "a") {
    if (admin) return "a-admin"
    return "a"
  } else if (cmd === "b") {
    if (admin) return "b-admin"
    return "b"
  }
  return "none"
}

// GOOD — table + early return (lint can count this)
const TABLE: Record<string, { user: string; admin: string }> = {
  a: { user: "a", admin: "a-admin" },
  b: { user: "b", admin: "b-admin" },
}
export function route(cmd: string, admin: boolean): string {
  const row = TABLE[cmd]
  if (!row) return "none"
  if (admin) return row.admin
  return row.user
}
```

## Done

Cite the exact lint command and green output on the files you touched. Same standard as `testing.mdc`.
