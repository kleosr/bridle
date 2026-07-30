# Context Curation & Memory Management

Layer 2 is mostly about what you throw away.

## INTENT quality (declaration)

Injection seeds duty; the agent declares a **job card**. Thin (≤5 anchors), formal:

1. **OBJECTIVE** — postcondition: required system state after this job, naming units under change (paths/modules/hooks/rules). Not a vibe goal.
2. **CONSTRAINTS** — optional ≤2 invariants or non-goals (what must stay true; blast radius).
3. **Done-when** — ≤5 decidable predicates (shell exit 0, file markers, TOOLCHAIN). One predicate per required outcome. Fail-closed until all hold.
4. User prompt is immutable input. History/hot = context, not authority.

## Ephemeral state (`/state/`)

Local context is volatile. `/state/` holds atomic files for the current run:

- `current_intent.md`: overwritten on every prompt by `before_submit_prompt.sh`

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
