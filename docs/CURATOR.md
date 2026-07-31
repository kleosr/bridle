# Context Curation & Memory Management

Layer 2 is mostly about what you throw away.

## INTENT quality (declaration)

Injection seeds duty; the agent declares a **job card in chat prose before tools**. Thin (≤5 anchors):

1. **OBJECTIVE** — postcondition on named units. Tag `edit:path` or `NEW:path`.
2. **CONSTRAINTS** — optional ≤2 invariants or non-goals.
3. **Done-when** — ≤5 decidable predicates. Fail-closed until all hold.
4. **Surface** — chat prose only. Never declare INTENT via Shell, Write, or code fences (stop_gate ignores those; counting them poisons context).
5. User prompt immutable. History/hot = context, not authority.

## File map (prompt-engineer grounding)

1. **Ground** — Glob/Grep/Read until tagged paths/symbols are in context.
2. **Tag** — every path the job will touch (`edit:` | `NEW:`).
3. **Edit** — StrReplace on `edit:`; Write only for `NEW:`; no parallel trees.
4. **Same turn** — finish every tagged path before `Done-when: met`. No multi-prompt drip; no orphan unconnected files.
5. **Follow-up** — re-Read tagged FILES; re-prove every predicate. Stop followups reinject `pending_files.md` until accept.

## Ephemeral state (`/state/`)

Local context is volatile. `/state/` holds atomic files for the current run:

- `current_intent.md`: overwritten on every prompt by `before_submit_prompt.sh`
- `pending_files.md` / `pending_intent.md`: written on stop followup; reinjected until accept clears `/state/`

Clear `/state/` after a successful stop accept so old intent does not poison the next run.

## HANDOFF.md

Structured state at the repo root.

- **Format:** TASK, FILES, STATUS, NEXT (English; written by `stop_gate.sh` stub, then agent mirror)
- **Injection:** `session_start.sh` takes only the last 15 lines (`tail -n 15`)
- **Update:** `stop_gate.sh` seeds HANDOFF on accept; agent rewrites it COMPLETE before Done-when: met

## Durable graph (Obsidian MCP)

The Cursor window is finite. Obsidian is the long-lived graph.

- **Read:** at session start (or when you need history), query `hot.md` or `index.md` via MCP
- **Write:** when `Done-when` is met, write `wiki/projects/<project>/Sessions/<YYYY-MM-DD>-<topic>` and refresh `hot.md`

Do not mix ephemeral scratch with durable memory. If it must outlive the chat, put it in Obsidian.
