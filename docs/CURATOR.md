# Context Curation

Layer 2 is mostly about what you throw away.

## INTENT quality (declaration)

Injection seeds duty; the agent **grounds first**, then declares a **job card in chat prose before Write**. Thin (≤5 anchors):

1. **OBJECTIVE** — postcondition on named units (what is true when done). Not a task ("implement X"). Tag `edit:path` or `NEW:path`. stop_gate rejects weak (`done`/`fixed`) and task-shaped OBJECTIVEs.
2. **CONSTRAINTS** — optional ≤2 invariants or non-goals.
3. **Done-when** — ≤5 decidable predicates. Fail-closed until all hold.
4. **Surface** — chat prose only. Never declare INTENT via Shell, Write, or code fences (stop_gate ignores those; counting them poisons context).
5. User prompt immutable. History/HANDOFF = context, not authority.

## File map (prompt-engineer grounding)

1. **Ground** — Glob/Grep/Read THIS codebase for the user's request. Do not invent paths. Read every file you will tag.
2. **Tag** — every path the job will touch (`edit:` | `NEW:`).
3. **Edit** — StrReplace on `edit:`; Write only for `NEW:`; no parallel trees.
4. **Same turn** — finish every tagged path before `Done-when: met`. No multi-prompt drip; no orphan unconnected files.
5. **Follow-up** — re-Read tagged FILES; re-prove every predicate. Stop followups reinject `pending_files.md` until accept.

## Ephemeral state (`/state/`)

Local context is volatile. `/state/` holds atomic files for the current run:

- `current_intent.md`: overwritten on every prompt by `before_submit_prompt.sh`
- `pending_files.md` / `pending_intent.md`: written on stop followup; reinjected until accept clears `/state/`
- `edit_velocity.log`: tracks per-file edit count for lean_gate velocity check

Clear `/state/` after a successful stop accept so old intent does not poison the next run.

## HANDOFF.md

Structured state at the repo root.

- **Format:** Active Objective, Current State, Constraints, Recent Verified Changes, Failed Attempts, Open Risks, Next Actions, Done-When, Archived.
- **Injection:** `session_start.sh` takes only the last 15 lines (`tail -n 15`)
- **Update:** `stop_gate.sh` seeds HANDOFF on accept; agent rewrites it COMPLETE before Done-when: met
- **Compaction:** if active sections exceed ~150 lines, compress older context into Archived. Keep active state small.

## Durable memory

Local `HANDOFF.md` is the brain — no external tools required.

Do not mix ephemeral scratch with durable state. If it must outlive the chat, put it in HANDOFF.
