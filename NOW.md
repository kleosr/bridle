# NOW.md

## Now

Session file is `NOW.md`. Security SSOT is `SECURITY.md`. Skill `/now`.

Seven-role team book is retired. Identity is User Rules charter plus Cursor + Grok lock. Specialists left: hunter, cut, prove.

## State

Five events: sessionStart, beforeSubmitPrompt, beforeShellExecution, beforeReadFile, stop. Local `~/.cursor` install. `scan.roots` empty. No preToolUse.
Always-on rules: agent, ponytail, pnpm, complexity, vibe (5). Path-scoped: testing, next, vite, astro, postgres, types.
`stop.sh` + `lib/diff_gate.sh`: unrequested rewrite (>50% of tracked file, ≥80 LOC) + mass reindent (whitespace-only churn) + duplicate helper. One `followup_message`, `loop_limit: 1`. Cloud json unchanged (no stop).

## Limits

Never Lane-A into this pack. No `updated_input`. Secrets never in this file, chat, or paste.
Do not invent a new rule system. Do not thin the charter. Edit books only in this repo.

## Proof

- `bash tests/run.sh` — 177 PASS, 0 FAIL (2026-09-03 14:15, churn gates replace loc_roof)
- `bash scripts/doctor.sh` — ALL CHECKS PASSED; live checksum match 8 files incl. stop.sh, lib/diff_gate.sh
- `FORCE=1 bash scripts/install.sh` — live `~/.cursor/hooks.json` has 5 events
- Audit: `docs/runtime-grounding-audit.md`; system: `docs/engineering-system.md`; ADR 2026-09-03 in `docs/DECISIONS/hooks-architecture.md`

## Next

Re-paste `shared/rules/USER-RULES.paste.txt` (Session Protocol now lists stop). Open a new chat so root AGENTS.md reloads (stale-in-session finding).
Open: observe a positive glob-rule activation in a TS/JS repo; verify `stop` on cloud before adding it to `hooks.cloud.json`.

## Archived

2026-08-28: local pack, vernacular retired, hunter/cut/prove.

<!-- COMPACTION PROTOCOL
When the active sections above (before this line) exceed ~150 lines:
1. Move older Now/Proof into Archived.
2. Keep Now, State, Limits, Proof, Next current.
3. Delete Archived older than the last 2 sessions.
4. Active section stays under ~150 lines.

session_start.sh injects Now, State, Limits, Proof, and Next.
Update this file only when state meaningfully changes.
-->