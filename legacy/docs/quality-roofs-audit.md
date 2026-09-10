# Quality roofs

Numbers are SSOT in `complexity.mdc`, `ponytail.mdc`, `testing.mdc`, `types.mdc`. This file is a map, not a second canonical source. Paste points at those files. Do not add ten rule files.

| Metric | Law (summary; canonical in the named `.mdc`) |
|--------|-----|
| Cyclomatic | Repo lint if present (MEASURED). Else UNMEASURED: flat control flow, early returns; do not guess a score. Never above **22**; stricter wins. Explicit user exception only. Do not disable; unmeasured is not green. Scope: touched functions, not full repo. |
| Cognitive | **22** only if this repo already measures it. Do not add Sonar. |
| Halstead | **< 80** only if already measured. Do not add a tool. |
| File LOC | New code: ponytail hard **300**. Never **500**. Legacy >700: modules ≤300. Generated/vendor/lockfiles/migrations/declarative excluded. Split for cohesion, not count alone. `stop.sh` does not gate size; approved refactors exempt from churn. |
| Coverage | **100%** of the defined change scope (diff vs merge-base/HEAD, worktree+index, or named files) when a coverage job exists; risk-based, genuine exclusions ok. Evidence, not proof of correctness. Do not add a runner. |
| CRAP | **< 25** only if measured. |
| Mutants | **0** meaningful survivors on files you touched when a mutator exists; equivalent/irrelevant needs explicit justification. Do not add one. |
| Dead / redundant | Remove dead code the task introduced/obsoleted. Third occurrence: consider extract when same responsibility. `cut` on demand; never delete solely for a metric. |
| `any` / `unknown` | No TS `any` (Go differs). `unknown` may flow to a validator/untrusted container; narrow before trusted domain use. `types.mdc` alwaysApply GLOBAL. |

AlwaysApply count is **7** (agent, ponytail, pnpm, complexity, vibe, testing, types). Glob: next, vite, astro, postgres, supabase.

Not adopted: raising cyclo to 22 or LOC to 500; a total `unknown` ban; adding coverage/mutation/Sonar/Halstead to this Bash pack; a LOC hook; alwaysApply copies in this pack's `.cursor/rules`.

Correctness, security, maintainability, and task requirements outrank style metrics. LOC, caller counts, coverage, and prompt size are diagnostics, not objectives.

Cloud: paste + `AGENTS.md`. Local: paste + `~/.cursor/rules`. Loads: `docs/token-budget.md`.
