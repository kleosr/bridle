# NOW.md

## Now

Session file is `NOW.md`. Security SSOT is `SECURITY.md`. Skill `/now`.

Quality roofs encoded in existing alwaysApply `.mdc` + paste (not ten new files). Cyclo 10 never 22. LOC 300 never 500. types+testing alwaysApply; types is GLOBAL.

## State

Five events: sessionStart, beforeSubmitPrompt, beforeShellExecution, beforeReadFile, stop. Local `~/.cursor` install. `scan.roots` empty. No preToolUse.
Always-on rules: agent, ponytail, pnpm, complexity, vibe, testing, types (7). Path-scoped: next, vite, astro, postgres.
`stop.sh` + `lib/diff_gate.sh`: unrequested rewrite (>50% of tracked src file, ≥80 LOC) + mass reindent + duplicate helper. One `followup_message`, `loop_limit: 1`. Cloud json unchanged (no stop).
`.env.example` readable. Token prefixes word-bounded. `beforeReadFile` denies missing policy / non-JSON.

## Limits

Never Lane-A into this pack. No `updated_input`. Secrets never in this file, chat, or paste.
Do not invent a new rule system. Do not thin the charter. Edit books only in this repo.
Do not copy `stop` into `hooks.cloud.json` until a cloud turn is seen to receive `followup_message`.
Do not add coverage/mutation/Sonar/Halstead tools to this Bash pack.

## Proof

- `bash tests/run.sh` — pending this change
- `bash scripts/doctor.sh` — pending this change
- Audit: `docs/quality-roofs-audit.md`

## Next

Re-paste `shared/rules/USER-RULES.paste.txt` into Cursor Settings → User Rules (Retrieval harness now carries the quality roofs). Open a new chat so root AGENTS.md reloads.
Open: observe a positive glob-rule activation in a TS/JS repo; verify `stop` on cloud before adding it to `hooks.cloud.json`.
GitHub repo description still says HANDOFF (API is read-only here).

## Archived

2026-09-04: quality roofs mapped onto complexity/ponytail/testing/types + paste.
2026-09-03: stop hook + runtime grounding audit. Proof claimed 177 PASS; Linux CI was red (`sed -i ''`).

<!-- COMPACTION PROTOCOL
When the active sections above (before this line) exceed ~150 lines:
1. Move older Now/Proof into Archived.
2. Keep Now, State, Limits, Proof, Next current.
3. Delete Archived older than the last 2 sessions.
4. Active section stays under ~150 lines.

session_start.sh injects Now, State, Limits, Proof, and Next.
Update this file only when state meaningfully changes.
-->
