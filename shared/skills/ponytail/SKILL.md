---
name: ponytail
description: >
  Native Lean quality bar: no code → reuse → stdlib → platform → installed dep
  → one line → minimum. Split recovery, neighbor match, types, trust floors.
  Use when writing app code or when thin ponytail.mdc points here.
---

# Ponytail

Thin roof: `shared/rules/ponytail.mdc`. This file is the quality bar. Only two churn patterns are hook-checked (`stop.sh`: unrequested rewrite, mass reindent); the rest is judgment.

## Ladder

Stop at the first rung that still does the job after reading the ask and the touched code:

1. NO CODE — config, delete, existing API.
2. Reuse — Grep this repo.
3. Stdlib of the language.
4. Framework native (React/Node/platform).
5. Already-installed dependency (new package needs one chat line why lower rungs fail).
6. One clear line.
7. Minimum — shortest correct private-native diff. Prefer files under soft ~80 LOC. Split before 120. Do not grow past 300. Never 500. Files >700 LOC: rewrite into modules ≤300 (`Write` new, `StrReplace` original and callers to imports). Zero prose comments. One job per file.

Soft Rule: skipping a rung needs one chat line naming why lower rungs fail.

## Quality (every Write)

Correct first. Then small. Then pretty.

- Match 1–2 sibling files in the directory before Write (imports, naming, error idiom).
- Named exports. Early return. Nesting depth ≤2.
- Types: no `any`, no un-narrowed `unknown`, no blind casts; prefer `type`; public signatures explicit.
- Zero prose comments (machine directives only: shebang, pragma, license, `@ts-expect-error`, lint directives).
- Zero dead code, zero redundant code. No unused imports, empty `catch`, leftover `console.log`, or `TODO` without a ticket id.
- Infer loading from data. Do not add `isLoading` when `data` starts null.
- Jargon: `bans.txt` next to this skill (fail-open if missing).
- Behavior change: add or update a test when the testing skill applies. Cite TOOLCHAIN green.

```ts
// BAD — new helper, any, narrating comment, nested pyramid
export default function run(x: any) {
  // fetch the user then do work
  if (x) {
    if (x.ok) {
      return x.data
    }
  }
}

// GOOD — reuse neighbors, named export, early return, typed
export function userName(row: { name: string } | null): string {
  if (!row) return ""
  return row.name
}
```

## Refactor

- File near 300 LOC: extract first, then add.
- File already >700 LOC: rewrite now. Reducing edits allowed; growth not.
- Third real repetition → extract. Two copies are cheaper.
- Shared change: Grep callers; blast-radius in chat.
- Prefer deletion over wrappers. No Nx/Clean Architecture theater.

`domains/` trees: [domains-ddd.md](domains-ddd.md). Split `frontend/` + `backend/`: [fe-be-layout.md](fe-be-layout.md).

## Split recovery

1. `Read` the file.
2. Plan split (functions → new modules beside neighbors).
3. `Write` new small files under roof.
4. `Write` original with imports.
5. `Grep` old import paths; `StrReplace` callers.
6. Retry the original diff. Never Shell sed/echo>/tee — `before_shell.sh` denies it.

## Floors (never skip)

Trust boundaries, authz, data-loss errors, a11y, explicit user asks. Cyclomatic: `complexity.mdc` (repo cap, else 10, never 22). Do not disable lint.

Cursor tools: Write, StrReplace, Shell, Read, Grep, Delete, Task, Glob, EditNotebook.

Off only: user says stop ponytail / normal mode.
