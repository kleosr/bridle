# Quality roofs

Numbers are SSOT in `complexity.mdc`, `ponytail.mdc`, `testing.mdc`, `types.mdc`. Paste points at those files. Do not add ten rule files.

| Metric | Law |
|--------|-----|
| Cyclomatic | Repo lint, else write to **10** unmeasured. Never above **22**; stricter wins. Do not disable; unmeasured is not green. |
| Cognitive | **22** only if this repo already measures it. Do not add Sonar. |
| Halstead | **< 80** only if already measured. Do not add a tool. |
| File LOC | New code: ponytail hard **300**. Never **500**. Legacy >700: modules ≤300. `stop.sh` does not gate size; approved refactors exempt from churn. |
| Coverage | **100%** of code you added/changed this turn when a coverage job exists; risk-based, genuine exclusions ok. Do not add a runner. |
| CRAP | **< 25** only if measured. |
| Mutants | **0** survivors on files you touched when a mutator exists; documented equivalent/unreachable ok. Do not add one. |
| Dead / redundant | Zero. Third copy → extract. `cut` on demand (cohesion, not caller count). |
| `any` / `unknown` | No TS `any` (Go differs). No un-narrowed `unknown` stored/passed; narrow at boundaries. `types.mdc` alwaysApply GLOBAL. |

AlwaysApply count is **7** (agent, ponytail, pnpm, complexity, vibe, testing, types). Glob: next, vite, astro, postgres, supabase.

Not adopted: raising cyclo to 22 or LOC to 500; a total `unknown` ban; adding coverage/mutation/Sonar/Halstead to this Bash pack; a LOC hook; alwaysApply copies in this pack's `.cursor/rules`.

Correctness, security, maintainability, and task requirements outrank style metrics. LOC, caller counts, coverage, and prompt size are diagnostics, not objectives.

Cloud: paste + `AGENTS.md`. Local: paste + `~/.cursor/rules`. Loads: `docs/token-budget.md`.
