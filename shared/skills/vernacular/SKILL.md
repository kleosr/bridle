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
1. Read thin vernacular rule first.
2. Follow hard bans.
3. Use sections below for stack-specific shape.
4. If no contract: private-match siblings only. Do not invent dialect.

## Match neighbors (before Write)
Before `Write` in a directory: `Read` 1–2 sibling files. Match their import grouping, naming, and error/result idiom. Do not invent a parallel dialect in the same folder.

## TypeScript / React / Node
- Comments: **zero prose**. Machine directives only (`#!`, pragma, license, build-guard, `@ts-expect-error`, eslint/prettier directives). Enforced by `lean_gate` on **projected whole file** (`comment_ratio_max=2`).
- Names: self-documenting; never narrate what the next line does.
- State: `if (!data) return <Loading/>` — no redundant isLoading when data starts null.
- Returns: early-return; max nesting depth 2.
- Types: strict; no `any`; prefer `type`; no blind casts.
- Async: async/await; no try/catch that only logs/swallows — match repo error idiom.
- Exports: named only. No default exports.
- Dead code / TODOs: delete or ticket-ref (`TODO(AUTH-12):`). No `// implement later`, empty `catch {}`, debug `console.log` left behind.
- Imports: no unused; group/stable style matching neighbors.
- Functions: one responsibility; extract before soft LOC 150 (`file_loc_soft`); hard deny at 700.
- Tests: behavior changes need tests when testing skill applies; cite `docs/TOOLCHAIN.md` evidence before Done.

## Cursor tools (primary vocabulary)
Use: `Write`, `Shell`, `Read`, `Grep`, `Delete`, `Task`, `Glob`.
Do not prefer Claude-only names (`Bash`, `StrReplace`, `MultiEdit`, `Edit`) in chat/examples — hooks may still accept those as aliases.

## INTENT
- Declare `INTENT:` as **chat prose before any tool** (never Shell/Write/fence).
- Tag every path `edit:path`|`NEW:path`. Done-when ≤5 decidable predicates. Finish all tags this turn.
- stop_gate audits assistant prose from `transcript_path`.

## Bash hooks (`shared/hooks/*.sh`)
Cursor-native emit (exit 0 so messages survive; non-zero only for failClosed parse failures):

    echo '{"permission":"allow"}'
    # deny: {"permission":"deny","user_message":"..."}
    # sessionStart: {"additional_context":"..."}
    # beforeSubmitPrompt: {"continue":true|false}
    # stop: {"followup_message":"..."}

Banned: `updated_input`, Python/Node gates, external APIs, `cd` in hooks.
Required: jq; event-hook entrypoints ≤80 LOC.

## Markdown & HANDOFF
- Bullets/tables. No fluff. System docs max 80 lines.
- HANDOFF: TASK / FILES / STATUS / NEXT.

## JSON
- Strict JSON (no comments). One roof per policy file (`lean.json`, `intent.json`).

## Anti-patterns
- Foreign UseCase/Repository theater.
- Shell bypass of `Write`/`Read`/`Grep`.
- Claiming gates enforce ungated prose essays.
