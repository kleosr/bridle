# NOW.md

## Now

Session file is `NOW.md`. Security SSOT is `SECURITY.md`. Skill `/now`.
Caps live in `complexity.mdc` / `ponytail.mdc` / `testing.mdc` / `types.mdc`. Paste restates them once for cloud.
Ground the files you will change. Proof is the command this change can break.

## State

Five events: sessionStart, beforeSubmitPrompt, beforeShellExecution, beforeReadFile, stop. Local `~/.cursor` install. `scan.roots` empty. No preToolUse.
Always-on rules: agent, ponytail, pnpm, complexity, vibe, testing, types (7). Path-scoped: next, vite, astro, postgres.
`session_start.sh` points at NOW.md (path only). Token-like NOW → quiet. Plan mode → quiet.
`stop.sh` + `lib/diff_gate.sh`: unrequested rewrite (>50% of tracked src file, ≥80 LOC) + mass reindent + duplicate helper. One `followup_message`, `loop_limit: 1`. Cloud json unchanged (no stop).
`.env.example` readable. Token prefixes word-bounded. `beforeReadFile` denies missing policy / non-JSON.

## Limits

Never Lane-A into this pack. No `updated_input`. Secrets never in this file, chat, or paste.
Do not invent a new rule system. Do not thin charter headings, hook steel, or roof text in the four `.mdc` files.
No nested `AGENTS.md` under `shared/` (root file wins; adapters re-attached on every Read).
Do not copy `stop` into `hooks.cloud.json` until a cloud turn is seen to receive `followup_message`.
Do not add coverage/mutation/Sonar/Halstead tools to this Bash pack.

## Proof

- `bash tests/run.sh` — 266 PASS, 0 FAIL (2026-09-06; living-docs + Windows stop parity)
- `bash scripts/doctor.sh` — ALL CHECKS PASSED
- Always-on: `docs/token-budget.md` (session ~11.6kB / ~2.9k tok; was ~15.7kB / ~3.9k tok)
- On-demand: skill bodies 22k→10k; hunter/cut/prove 15k→6k. Living docs 84k→13k (`_archive/`).
- Windows `install.ps1` copies `stop.sh` + `diff_gate.sh` (same set as `fleet_install.sh`).
- Audit: `docs/quality-roofs-audit.md`; article https://x.com/i/article/2095989703967125509

## Next

Reinstall: `git pull && FORCE=1 bash scripts/install.sh`. Re-paste `shared/rules/USER-RULES.paste.txt` (install cannot write Settings). New chat so rules reload.
Open: observe a positive glob-rule activation in a TS/JS repo; verify `stop` on cloud before adding it to `hooks.cloud.json`.
GitHub repo description still says HANDOFF (API is read-only here).

## Archived

2026-09-06: full pack lean — skills/agents rewritten, docs/_archive, SOURCE.md, budget+install caps.
2026-09-05: Astra slim (AGENTS.md navigator). Then deleted nested `shared/*/AGENTS.md` + `docs/astra-slim.md`.
2026-09-04: quality roofs mapped onto complexity/ponytail/testing/types + paste.

<!-- COMPACTION PROTOCOL
When the active sections above (before this line) exceed ~150 lines:
1. Move older Now/Proof into Archived.
2. Keep Now, State, Limits, Proof, Next current.
3. Delete Archived older than the last 2 sessions.
4. Active section stays under ~150 lines.

session_start.sh points at this file (path only). Read Now, State, Limits, Proof, and Next.
Update this file only when state meaningfully changes.
-->
