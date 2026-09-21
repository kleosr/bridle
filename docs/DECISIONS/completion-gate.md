# Architecture Decision Record: The Completion Gate

**Status:** Accepted & Enforced
**Context:** Closing the request → completion loop with a deterministic integration/completeness sensor and a confidence-scored verdict.

## Problem

Bridle already enforced the *inputs* to good work (secret gates, shell gates), the *shape* of a change (churn/size at stop), *state* (`features.json` tree-hash staleness), and *verification discipline* (`testing.mdc`, `prove`). What it did not have was a deterministic sensor for the failure mode Loop Engineering calls **overconfident termination**: the agent stops after producing code that parses and even compiles but is *not integrated* — a new module nobody imports, a stub that throws, an unresolved conflict marker, a changed file that no longer parses.

"The refactor looks complete" is a judgement. A machine-checkable condition is not. The completion gate turns the end-to-end completeness of a change into a machine signal, so the loop can **act when confidence is high and escalate when it is not**, instead of trusting the model's own "done".

## Decision

Add one sensor library and one scorer, within the frozen four-hook surface:

The detectors are split by job and cost so the per-turn hook never pays for whole-repo analysis:

- `shared/hooks/lib/complete_gate.sh` — the **cheap half**, safe on the stop hook: conflict markers, not-implemented stubs, ownerless TODOs, and the shared change-surface primitives (`comp_changed_paths`, `comp_added_lines`). No whole-repo scan.
- `shared/hooks/lib/complete_graph.sh` — the **whole-repo half**, CLI-only via `scripts/complete.sh` (sourced after the gate, whose primitives it reuses): orphan reachability, dangling reference integrity, and the import extractor behind dependency integrity. The stop hook never loads it.

Deterministic detectors over the working tree vs `HEAD`:
  - **conflict**: files containing both `<<<<<<<` and `>>>>>>>` markers (genuine unresolved merge).
  - **stub**: not-implemented sentinels added in the change (`throw new Error('TODO…')`, `NotImplementedError`, `todo!()`, `unimplemented!`).
  - **orphan**: a source module *added* by the change whose basename is never referenced by any other file — added but not wired/registered/imported. Uses transitive reachability from pre-existing anchors, so a disconnected island of new files that only import each other is also caught. Entrypoints (`index`, `main`, `__init__`…), framework auto-discovery dirs (`app/`, `pages/`, `routes/`, `migrations/`…), and test files are excluded so the detector stays high-precision.
  - **dangling** (reference integrity): a declaration *removed* by the change (exported JS/TS symbol, python `def`/`class`, go `func`) that no longer resolves anywhere yet is still referenced by surviving code — the incomplete-refactor regression (delete/rename an export, leave a caller behind). Renames with all callers updated, symbols moved to another file (still declared), and deletions of genuinely unused exports are not flagged. This is the mirror of orphan: orphan is added-but-unused, dangling is removed-but-still-used. Grounded in the largest real-world failure symptom — "partial fix / incomplete logic" — reported for frontier models on SWE-bench Verified.
  - **undeclared** (dependency integrity): a package *newly imported* by the change (JS/TS) that is not declared in any `package.json` in the tree. Relative paths, `node:` and Node core modules are excluded; scoped and subpath specifiers are normalized to the installable package. The declared set is the union across all manifests, so a monorepo's per-package dependency is not a false positive. Grounded in the ~25% "tool/API misconfiguration — added a dependency without verifying" failure class. jq-backed (manifest parse), so it lives in `scripts/complete.sh`; the extractor `comp_added_imports` is in the gate library and is hook-safe.
  - **todo**: ownerless `TODO/FIXME/XXX/HACK` added in the change (a light nudge, not a block).
- `scripts/complete.sh check [dir]` — aggregates those signals plus changed-file syntax (reusing `verify_gate.sh`). The JSON leads with `counts` and `signals`. `confidence` (0-100) only selects the exit: `act` (exit 0) when confidence ≥ `COMPLETE_MIN_CONFIDENCE` (default 80), else `escalate` (exit 3). Conflicts and syntax errors are *critical* → confidence 0. A caller loop or CI step branches on the exit code. Cite the counts, not the number alone.
- `stop.sh` gains `gate_completion` — the **cheap, near-zero-false-positive** subset (conflicts + stubs) surfaced as one advisory per turn. Orphan analysis is intentionally *not* in the hook: scanning the whole repo for references is a completion-time question, not a per-turn one, and keeping it out of the hook avoids nagging on every new file.

## Why this layer, not a rule or a fifth hook

- **Deterministic over remembered.** Per `engineering-os.md`, a guide is a rule and a sensor is code. "Check that your new module is actually imported" is a sensor: it belongs in code, not in a prompt the model may forget on turn 10.
- **Hook freeze holds.** No new hook event. The stop hook already fires once per turn and is the correct place for a cheap advisory; the expensive graph scan lives in an on-demand script.
- **Advisory, not a block.** `stop.sh` remains advisory (`testing.mdc`): the gate names unfinished wiring; it never refuses completion. The blocking authority stays with the human and the real verify command.
- **Not a second loop.** `complete.sh` and `bench.sh` are pure analyzers — no model calls, no ReAct loop — so the `noPackLoop` invariant holds.

## Verification

- `tests/complete_edges.sh` — stop advisory on conflicts/stubs, quiet on wired edits and lone orphans, and the full `complete.sh` scoring/verdict/exit contract.
- `scripts/bench.sh` over `evals/bench/cases.json` — a labelled corpus (unwired orphan, conflict, stub, syntax-red vs. wired module, entrypoint, framework route, migration, test, clean edit, lone TODO). It reports accuracy / precision / recall / false-positive-rate and the before/after against the no-detection baseline, and is itself gated in the eval index (`integration` dimension).

## Scope and limits

The scorer measures the **shape** of a change, not program behavior. It cannot prove a feature works — that is the repo verify command's job, and citing a real run stays the definition of "done". Orphan detection is a high-precision heuristic, not a full call-graph; it is advisory and errs toward silence (framework-discovered files are skipped). What it buys is a deterministic, cheap, continuous answer to one question the model is systematically overconfident about: *is this change actually wired in, or did it stop halfway?*
