# Quality Roofs Audit — 2026-09-04

**Request:** encode ten quality metrics as always-on law, and confirm User Rules still work.  
**Decision:** extend existing alwaysApply `.mdc` + the User Rules paste. Do not add ten new rule files. Do not weaken roofs this pack already has.

## Asked vs law today

| Metric | Asked | Law before this change | Decision |
|--------|-------|------------------------|----------|
| Cyclomatic | < 22 | `complexity.mdc`: repo lint, else **10**; hook denies lint-disable | Keep **10** as the working cap. **22** is a never-exceed ceiling (extract; do not raise a repo cap toward 22). |
| Cognitive | < 22 | Skill: do not switch to Sonar unless the repo already uses it | Cap **22** only when the repo already measures it. Do not add Sonar/sonarjs. |
| Halstead difficulty | < 80 | Absent | Cap **80** only when the repo already measures it. Do not add a Halstead tool. This pack is Bash/jq; no Python/Rust metric runner. |
| File LOC | < 500 | `ponytail.mdc`: soft ~80, split before 120, **hard 300**, >700 rewrite | Keep **300**. **500** is a never-exceed ceiling so 500 is not permission to grow past 300. `stop.sh` still does not gate file size (drive-by split rejected 2026-09-03). |
| Coverage | 100% | `testing.mdc` glob-only; skill: coverage is a smoke detector, not a trophy | **100% of code you added or changed this turn** when a coverage job already exists. Cite that job. Do not add a coverage runner. Whole-repo 100% is not a reason to test getters or mock internals. |
| CRAP | < 25 | Absent | Cap **25** only when measured. At 100% coverage CRAP equals cyclomatic, so cyclo≤10 already implies CRAP≤10 on covered code. |
| Surviving mutants | 0 | Skill: do not invent mutation theater | **0 survivors** on files you touched when a mutator already runs. Do not add Stryker/PIT/mutmut. |
| Dead code | 0 | `ponytail.mdc` Quality; `cut` on demand | Keep as always-on law in ponytail. `cut` stays the specialist, not a new alwaysApply file. |
| Redundant code | 0 | ponytail: third copy → extract; two copies are cheaper | Same. Spell "zero redundant" in the roof. |
| `any` / `unknown` | none | ponytail: no `any`; `types.mdc` glob + project-layer; `unknown` not banned | No `any`. No un-narrowed `unknown` (not a total ban: catch/JSON/IO may bind `unknown` if the next statements narrow it). `types.mdc` becomes alwaysApply and GLOBAL. |

## Why not ten new alwaysApply files

- NOW.md Limits: do not invent a new rule system.
- `docs/engineering-rules-decision.md`: efficiency is what the pack refuses to load. Five alwaysApply files was the 2026-09-03 ceiling; this change adds two (`testing`, `types`) by flipping flags, not by creating `quality.mdc` / `halstead.mdc` / `crap.mdc`.
- Duplicate headings are banned (`tests/grounding.sh`). Ten new files would either collide (`# Complexity`, `# Types`) or dump the same numbers in two canons.
- Cognitive / Halstead / CRAP / mutants / coverage have **no consumer in this pack's TOOLCHAIN**. Encoding them as "install this linter" would violate "no pack Python" and the complexity skill's "do not add a linter stack the repo does not have."

## User Rules (working / not)

| Surface | Status |
|---------|--------|
| `USER-RULES.paste.txt` | Canonical charter. This cloud session already loads it as User Rules (sections Identity → Cursor + Grok). Charter lock: do not thin, summarize, or reorder those sections. Quality numbers are **added inside Retrieval harness**, where cyclomatic already lived. |
| Cursor Settings paste | Manual. Install prints "paste → User Rules." After this change the operator must **re-paste** or Settings still has the pre-roof paragraph. No hook can write Settings. |
| Cloud on this pack | `~/.cursor/rules` is absent. alwaysApply `.mdc` do not load. Cloud law is paste + root `AGENTS.md`. That is why the paste paragraph is mandatory, not optional commentary. |
| Local IDE after `FORCE=1 bash scripts/install.sh` | alwaysApply `.mdc` load from `~/.cursor/rules`. Paste still required as charter floor. |

## Topology change: `types.mdc`

Before: SHARED / pack `.cursor/rules` only / glob / `alwaysApply: false`. Tests: "install does not copy types.mdc to user rules."

After: GLOBAL / `~/.cursor/rules` / `alwaysApply: true`. Pack `.cursor/rules` must not keep a copy (same prune as `agent.mdc`). Lane-A `project-hooks` still copies GLOBAL, so cloud target repos still get `types.mdc`.

`SHARED=()` — no project-layer rule remains. `fleet_sync.sh sync` no longer copies types into scanned repos; those repos pick it up from the user rules dir.

## Always-on count

`grep -l '^alwaysApply: true' shared/rules/*.mdc` = **7**: agent, ponytail, pnpm, complexity, vibe, **testing**, **types**. Glob remains: next, vite, astro, postgres.

## Not adopted

- Raising the default cyclomatic cap from 10 to 22.
- Raising the file roof from 300 to 500.
- A total ban on `unknown` (would force `any` at `catch` / `JSON.parse` under `useUnknownInCatchVariables`).
- Adding coverage, mutation, Sonar, or Halstead tooling to this Bash pack.
- Registering a hook for LOC / complexity / coverage (rejected 2026-09-03 for LOC; still judgment + lint).
- Putting alwaysApply `.mdc` into this pack's `.cursor/rules` (double-load locally; 2026-09-03 decision (a)).
