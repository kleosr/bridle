---
name: vernacular
description: >
  Private dialect + V2 anti-slop stack guides (TS/React, Bash hooks, Markdown,
  JSON, state, INTENT). Read when vernacular.mdc globs match or user asks naming
  / native match / anti-slop. Thin rule holds hard bans; this skill holds examples.
---

# Vernacular (fat skill)

Thin roof: `shared/rules/vernacular.mdc` (hard bans). This file = procedure + examples.

## Load order
1. Read `.cursor/rules/vernacular.mdc` (or VERNACULAR.md).
2. Follow hard bans from the thin rule first.
3. Use sections below for stack-specific shape.
4. If no contract: private-match siblings only. Do not invent dialect.

## TypeScript / React / Node
- Comments: no prose comments in app code; machine directives only (shebang, pragma, license header, build guard, ts-expect-error). The comment-ratio gate in `lean_gate.sh` enforces this mechanically.
- State: `if (!data) return <Loading/>` — no redundant isLoading when data starts null.
- Returns: early-return; max nesting depth 2.
- Types: strict; no any; prefer type; infer when clear.
- Async: async/await or chains; no try/catch that only logs.
- Exports: named only.

## Bash hooks (`shared/hooks/*.sh`)
Cursor-native output. Template:

    #!/bin/bash
    set -euo pipefail
    INPUT=$(cat)
    # parse with jq; emit Cursor JSON on stdout
    echo '{"permission":"allow"}'
    exit 0

Banned: updated_input, Python, Node, external APIs, cd in hooks.
Required: jq; max 80 LOC (event-hook entrypoints); never emit Claude
shapes (`hookSpecificOutput`). Emit shapes: `permission` (deny/allow),
`additional_context` (sessionStart), `continue` (beforeSubmitPrompt),
`followup_message` (stop).
Deny = `{"permission":"deny","user_message":"..."}` on stdout + **exit 0**
(Cursor parses stdout JSON on exit 0; a non-zero exit also denies via
failClosed but drops the message). Unparseable input: exit non-zero so
failClosed blocks.

## Markdown & HANDOFF
- Bullets/tables. No fluff.
- System docs max 80 lines (HANDOFF, ARCHITECTURE).
- HANDOFF: TASK / FILES / STATUS / NEXT.
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
