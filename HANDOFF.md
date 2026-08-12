# HANDOFF — Session State

## Active Objective

GROUND → INTENT → tags. No product allowlist. Read-before-Write is steel.

## Current State

Loop (correct order):
1. User prompt
2. GROUNDING — Grep/Glob/Read THIS codebase for what they named. Do not invent paths.
3. INTENT + OBJECTIVE + edit:|NEW: from those hits
4. Write/StrReplace only tagged paths; stop_gate audits; HANDOFF survives

Steel: pre_tool_use denies Write/Delete on a path not Read this session. NEW files need Grep/Glob first.
Steer: before_submit always says GROUNDING then JOB CARD on code prompts; Grep nouns from the prompt (not a neon/api special case).
Ponytail stays in always-apply mdc. Hooks are not a retriever — dumping rg hits would bias the model.

## Next Actions

- Local: `bash MacOS/install.sh` then re-paste USER-RULES.paste.txt

## Archived

macOS POSIX grep (wb_alt); Cursor-only tools; second-brain channels.

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