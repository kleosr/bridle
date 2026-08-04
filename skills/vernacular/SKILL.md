---
name: vernacular
description: >
  Private dialect + V2 anti-slop stack guides (TS/React, Bash hooks, Markdown,
  JSON, state, INTENT). Read when vernacular.mdc globs match or user asks naming
  / native match / anti-slop. Thin rule holds hard bans; this skill holds examples.
---

# Vernacular (fat skill)

Thin roof: `rules/vernacular.mdc` (hard bans). This file = procedure + examples.

## Load order
1. Read `.cursor/rules/vernacular.mdc` (or VERNACULAR.md).
2. Follow hard bans from the thin rule first.
3. Use sections below for stack-specific shape.
4. If no contract: private-match siblings only. Do not invent dialect.

## TypeScript / React / Node
- Comments: ban obvious what-comments; why-only if non-obvious.
- State: `if (!data) return <Loading/>` — no redundant isLoading when data starts null.
- Returns: early-return; max nesting depth 2.
- Types: strict; no any; prefer type; infer when clear.
- Async: async/await or chains; no try/catch that only logs.
- Exports: named only.

## Bash hooks (`hooks/*.sh`)
Template:

    #!/bin/bash
    set -euo pipefail
    INPUT=$(cat)
    # parse with jq; fail-closed
    echo '{"action":"allow"}'
    exit 0

Banned: updated_input, Python, Node, external APIs, cd in hooks.
Required: jq; exit non-zero on parse failure; max 80 LOC.

## Markdown & memory
- Bullets/tables. No fluff.
- System docs max 80 lines (HANDOFF, ARCHITECTURE).
- HANDOFF: TASK / FILES / STATUS / NEXT.
- Sessions: `wiki/projects/<project>/Sessions/<YYYY-MM-DD>-<topic>.md`
- Summaries not chat dumps.

## JSON
- Strict JSON (no comments).
- One roof per policy file.
- hooks.json: flat; camelCase event keys.

## Ephemeral state
- `/state/` atomic overwrite.
- `current_intent.md` = raw intent only.
- Clear on stop_gate success.

## Anti-patterns
- Foreign UseCase/Repository theater.
- Shell bypass of Write/StrReplace.
- Claiming gates enforce ungated prose essays.
