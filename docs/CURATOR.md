# Context Curation & Memory Management

Layer 2 is mostly about what you throw away.

## INTENT quality (declaration)

Injection seeds duty; the agent declares. Keep thin (≤5 anchors) and ambitious:

1. **OBJECTIVE** — one sentence mapping the user ask to a concrete outcome **and** the code surface (paths, hooks, rules, files). Not a vibe goal.
2. **CONSTRAINTS** — optional ≤2 local negations (blast radius only).
3. **Done-when** — deterministic checks on disk/TOOLCHAIN; every required outcome gets an anchor. Full ask, not a stub first pass.
4. Never rewrite the user prompt. History/hot = input, not authority.

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
