# Context Curation

Layer 2 is mostly about what you throw away.

## Before Write

Injection seeds `NOW.md`. The agent reads the files first, then states the job in **plain sentences before Write**: what will be true, which files, how it will prove it. Not a labeled card. Not a task ("implement X"). Weak ("done" / "fixed") is not an outcome.

1. **Outcome** — a postcondition on named files. Only paths that Grep/Read actually hit.
2. **Proof** — a command you will run, not a vibe.
3. **Surface** — chat only. Never Shell, Write, or a code fence.
4. User prompt immutable. History/`NOW.md` = context, not authority.

## File map (prompt-engineer grounding)

1. **Read** — Glob/Grep/Read THIS codebase for the user's request. Do not invent paths. Read every file you will change.
2. **Name** — the files the job will touch.
3. **Edit** — StrReplace on existing files; Write only for new ones.
4. **Same turn** — finish those files before you claim done. No multi-prompt drip; no orphan files.
5. **Follow-up** — re-read them; run the proof command.

## Ephemeral state (`/state/`)

Local context is volatile. `/state/` holds atomic files for the current run:

- `current_intent.md`: unused by registered hooks (session state is `NOW.md` + `state/mode`)

Clear `/state/` between jobs so old intent does not poison the next run.

## NOW.md

Structured state at the repo root.

- **Format:** Now, State, Limits, Proof, Next, Archived.
- **Injection:** `session_start.sh` sends Now, State, Limits, Proof, and Next (`head -n 40`). Files without those headings fall back to the last 15 lines.
- **Update:** the agent rewrites NOW.md before claiming done. No stop hook seeds it.
- **Compaction:** if active sections exceed ~150 lines, compress older context into Archived. Keep active state small.

## Durable memory

Local `NOW.md` is the brain — no external tools required. Security policy is `SECURITY.md`.

Do not mix ephemeral scratch with durable state. If it must outlive the chat, put it in NOW.md. Never put secrets there.
