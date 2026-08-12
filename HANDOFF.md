# HANDOFF — Session State

## Active Objective

macOS-first Cursor hooks: POSIX grep, JOB CARD + grounding, no Claude vocabulary.

## Current State

Done-when: met. 178/178 tests.

Day-to-day loop (unchanged contract, now Mac-safe):
1. Prompt in → before_submit classifies code, nudges GROUNDING + JOB CARD
2. Agent Grep/Read THIS codebase (reuse / ponytail.mdc always-apply)
3. Agent declares INTENT + OBJECTIVE + edit:|NEW: in chat before tools
4. stop_gate audits; HANDOFF survives

Ponytail is law in always-apply mdc, not a sessionStart essay.
Stock macOS: no GNU grep \b (BSD treats it as backspace). wb_alt() is the boundary.

## Next Actions

- Local: `bash MacOS/install.sh` then re-paste USER-RULES.paste.txt
- Windows: `.\Windows\install.ps1` now copies skills too

## Archived

(Older context compacted here when active sections exceed ~150 lines.)

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
