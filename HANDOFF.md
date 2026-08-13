# HANDOFF — Session State

## Active Objective

Native four-hook cut is live. Leftover unregistered scripts are deleted.

## Current State

`~/.cursor/hooks.json` is 4 events, `./hooks/*.sh`. 12 bash files, 667 LOC. Tests PASS:81 FAIL:0. Results canvas: canvases/hooks-native-cut.canvas.tsx.

## Constraints

Never Lane-A into this pack. Destructive literals stay in `policy/*.ere`. No `updated_input`.

## Done-When

- unregistered event scripts gone from shared/hooks
- `bash tests/run.sh` FAIL:0 and doctor ALL CHECKS PASSED
- results canvas written

## Next Actions

Optional clutter: unused tests/fixtures JSON, emit_followup in common.sh, intent.json unused by hooks.

## Archived

16-event harness cut then leftover delete 2026-08-12. Diagnosis canvas hooks-native-audit.canvas.tsx. 127 lockout was project-relative paths plus failClosed submit.

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
