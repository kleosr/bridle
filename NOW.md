# NOW.md

## Now

Session file is `NOW.md`. Security SSOT is `SECURITY.md`. Skill `/now`.
Caps live in `complexity.mdc` / `ponytail.mdc` / `testing.mdc` / `types.mdc`. Paste restates them once for cloud.
Ground the files you will change. Proof is the command this change can break.

## State

Five events: sessionStart, beforeSubmitPrompt, beforeShellExecution, beforeReadFile, stop. Local `~/.cursor` install. `scan.roots` empty. No preToolUse.
Always-on rules: agent, ponytail, pnpm, complexity, vibe, testing, types (7). Path-scoped: next, vite, astro, postgres.
`stop.sh` + `lib/diff_gate.sh`: unrequested rewrite (>50% of tracked src file, ≥80 LOC) + mass reindent + duplicate helper. One `followup_message`, `loop_limit: 1`. Cloud json unchanged (no stop).
`.env.example` readable. Token prefixes word-bounded. `beforeReadFile` denies missing policy / non-JSON.

## Limits

Never Lane-A into this pack. No `updated_input`. Secrets never in this file, chat, or paste.
Do not invent a new rule system. Do not thin charter headings, hook steel, or roof text in the four `.mdc` files.
No nested `AGENTS.md` under `shared/` (root file wins; adapters re-attached on every Read).
Do not copy `stop` into `hooks.cloud.json` until a cloud turn is seen to receive `followup_message`.
Do not add coverage/mutation/Sonar/Halstead tools to this Bash pack.

## Proof

- `bash tests/run.sh` — 236 PASS, 0 FAIL (2026-09-05; Astra article: proportional ground + proof)
- `bash scripts/doctor.sh` — ALL CHECKS PASSED
- Audit: `docs/quality-roofs-audit.md`; article https://x.com/i/article/2095989703967125509

## Next

Live `~/.cursor` synced (`FORCE=1 bash scripts/install.sh`, doctor live checksums match). Re-paste `shared/rules/USER-RULES.paste.txt` into Cursor Settings → User Rules (install cannot write Settings). Open a new chat so rules reload.
Open: observe a positive glob-rule activation in a TS/JS repo; verify `stop` on cloud before adding it to `hooks.cloud.json`.
GitHub repo description still says HANDOFF (API is read-only here).

## Archived

2026-09-05: Astra slim (AGENTS.md navigator). Then deleted nested `shared/*/AGENTS.md` + `docs/astra-slim.md`.
2026-09-04: quality roofs mapped onto complexity/ponytail/testing/types + paste.

<!-- COMPACTION PROTOCOL
When the active sections above (before this line) exceed ~150 lines:
1. Move older Now/Proof into Archived.
2. Keep Now, State, Limits, Proof, Next current.
3. Delete Archived older than the last 2 sessions.
4. Active section stays under ~150 lines.

session_start.sh injects Now, State, Limits, Proof, and Next.
Update this file only when state meaningfully changes.
-->
