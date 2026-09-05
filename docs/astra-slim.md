# Astra slim — 2026-09-05

Apply Eric Provencher / pvncher guidance (short skill descriptions, progressive disclosure, contextual docs, keep real boundaries) to **this pack only**. Roofs from PR #32 / `docs/quality-roofs-audit.md` are unchanged.

## What changed

| Surface | Before | After |
|---------|--------|-------|
| Root `AGENTS.md` | ~5k handbook that restated cyclo/LOC/coverage/`any` numbers | Navigator. Points at paste + four roof `.mdc` files. |
| `USER-RULES.paste.txt` | Same numbers inline with no SSOT label | Charter sections kept. Retrieval harness names the four `.mdc` files as canonical and restates the numbers **once** as the cloud floor. |
| Skill YAML `description` | Multi-line pick-me blurbs (some restated caps) | Short when-to-use. Procedure stays in `SKILL.md`; citations in `SOURCE.md` / `sources.md`. |
| `vibe.mdc` | Restated cyclo 10/22 | Points at `complexity.mdc`. |

`testing.mdc` stays `alwaysApply: true`. Coverage and mutant roofs apply to **code changed this turn**, not only test files. Glob-scoping would drop the roof on production writes. That was the #32 always-on choice.

## What must not be slimmed

- Hook steel: secret-prompt block, secret-path deny, destructive / Shell source-write deny, cyclomatic-lint disable deny, `stop.sh` churn gate.
- `SECURITY.md` and `policy/*.ere`.
- Charter headings in the paste (Identity → Cursor + Grok). Do not reorder or drop them.
- Roof **text** in `complexity.mdc`, `ponytail.mdc`, `testing.mdc`, `types.mdc`.
- Install / uninstall / fingerprint behavior.

## Why the paste still carries numbers

Cloud sessions on this pack do not load `~/.cursor/rules`. Law there is paste + this handbook. The handbook no longer dumps the caps; the paste still does, labeled as a restatement of the `.mdc` files.

## Astra map

- **Short desc** — skill `description` lines.
- **Progressive disclosure** — always-on roofs stay thin; skills and `SOURCE.md` load on demand; `AGENTS.md` is a map.
- **Contextual docs** — numbers live next to the rule that enforces them.
- **Real boundaries** — hooks and secret policy stay deterministic.
