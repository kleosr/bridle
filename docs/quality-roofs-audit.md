# Quality roofs

Numbers are SSOT in `complexity.mdc`, `ponytail.mdc`, `testing.mdc`, `types.mdc`. Paste restates them once (cloud floor). Do not add ten rule files.

| Metric | Law |
|--------|-----|
| Cyclomatic | Repo lint, else **10**. Never above **22**. Do not disable. |
| Cognitive | **22** only if this repo already measures it. Do not add Sonar. |
| Halstead | **< 80** only if already measured. Do not add a tool. |
| File LOC | Ponytail hard **300**. Never **500**. `stop.sh` does not gate size. |
| Coverage | **100%** of code you added/changed this turn when a coverage job exists. Do not add a runner. |
| CRAP | **< 25** only if measured. |
| Mutants | **0** survivors on files you touched when a mutator exists. Do not add one. |
| Dead / redundant | Zero. Third copy → extract. `cut` on demand. |
| `any` / `unknown` | No `any`. No un-narrowed `unknown`. `types.mdc` alwaysApply GLOBAL. |

AlwaysApply count is **7** (agent, ponytail, pnpm, complexity, vibe, testing, types). Glob: next, vite, astro, postgres.

Not adopted: raising cyclo to 22 or LOC to 500; a total `unknown` ban; adding coverage/mutation/Sonar/Halstead to this Bash pack; a LOC hook; alwaysApply copies in this pack's `.cursor/rules`.

Cloud: paste + `AGENTS.md`. Local: paste + `~/.cursor/rules`. Caps: `docs/token-budget.md`.
