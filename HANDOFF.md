# HANDOFF — Session State

## Active Objective

Session complete 2026-08-10 — global hook layer + multi-platform skeleton.

## Current State

Done-when: met. All work landed on master via PR (fresh branch
cursor/global-hooks-platform, linear over 69b8af4).
LIVE: ~/.cursor/hooks.json global single layer (10 events); repo-level
hooks removed from 3 fleet projects. 79/79 tests, doctor ALL PASSED.
Structure final: shared/{hooks,rules,skills,config} canonical core;
MacOS/ Linux/ Windows/ platform installers (+ wsl-shim.ps1).
Branch cursor/shared-system-reorg left as-is (superseded, not deleted).

## Next Actions

Test Windows/install.ps1 on a real Windows+WSL box. Watch gauntlet +
gauntlet-macos CI on master post-merge. Confirm DEBERES arrives 1× per
prompt under the global layer (live token-fix proof).

## Archived









(Older context compressed here when active sections exceed ~150 lines. See compaction protocol below.)

<!-- COMPACTION PROTOCOL
When the active sections above (before this line) exceed ~150 lines:
1. Move Recent Verified Changes older than the last 3 items into Archived.
2. Compress Failed Attempts into one-liners.
3. Keep Active Objective, Current State, Constraints, Next Actions, Done-When current.
4. Delete Archived entries older than the last 2 sessions.
5. The active section must stay under ~150 lines after compaction.

session_start.sh injects the last 15 actionable lines of this file as additionalContext
(the COMPACTION PROTOCOL block at the bottom is excluded).
Keep the bottom of this file as the most actionable context.

Update this file ONLY when state meaningfully changes — not on every small edit.
-->

(Older context compacted here when active sections exceed ~150 lines.)