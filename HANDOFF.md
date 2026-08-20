# HANDOFF — Session State

## Active Objective

sessionStart injects workspace HANDOFF.md via `workspace_roots[0]` when cwd is `~/.cursor`. Global macOS hooks match pack.

## Current State

sessionStart prefers hook JSON `workspace_roots[0]` for HANDOFF when that dir has HANDOFF.md or AGENTS.md; PWD/HERE walk remains fallback. Pack tests PASS:88 FAIL:0. `FORCE=1 bash MacOS/install.sh` after the fix. doctor ALL CHECKS PASSED. Lane-A not in pack. No preToolUse / no `updated_input`.

## Constraints

Never Lane-A into this pack. No `updated_input` / no preToolUse. Steel is a denylist, not secret isolation.

## Done-When

- Global hooks registered — met
- sessionStart finds workspace HANDOFF.md via `workspace_roots[0]` — met

## Next Actions

Mario: paste `shared/rules/USER-RULES.paste.txt` if Settings still has the old blob. New agent chat to fire sessionStart with workspace HANDOFF.

## Archived

Audit 2026-08-19: Architect READY, CTO APPROVE, QA GREEN, DevOps INSTALLED. Prior: native-lean-autoload prune; four-hook cut PR #17.

<!-- COMPACTION PROTOCOL
When the active sections above (before this line) exceed ~150 lines:
1. Move Recent Verified Changes older than the last 3 items into Archived.
2. Compress Failed Attempts into one-liners.
3. Keep Active Objective, Current State, Constraints, Next Actions, Done-When current.
4. Delete Archived entries older than the last 2 sessions.
5. The active section must stay under ~150 lines after compaction.

session_start.sh injects the last 15 actionable lines of this file as additional_context
(the COMPACTION PROTOCOL block at the bottom is excluded).
Keep the bottom of this file as the most actionable context.

Update this file ONLY when state meaningfully changes — not on every small edit.
-->