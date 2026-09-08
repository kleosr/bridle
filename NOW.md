# NOW.md

## Now

Security hooks fail closed. Uninstall is manifest-owned (preserves other `hooks.json` keys). `sessionStart` emits the NOW.md path only. `stop` is an advisory follow-up.

## State

Five events. Local `~/.cursor` install. `scan.roots` empty. No preToolUse.
Always-on: 7. Path-scoped: next, vite, astro, postgres, supabase.
GLOBAL SSOT: `shared/config/rules.global.txt`. Ownership: `shared/config/manifest.json`.
`beforeSubmitPrompt` / `beforeShellExecution` / `beforeReadFile` failClosed. Malformed shell payload denies.
Windows: Git Bash + jq shim; install merges hooks.json. `scripts/install.sh` refuses MINGW.

## Limits

Never Lane-A into this pack. No `updated_input`. Secrets never in this file, chat, or paste.
Do not invent a new rule system. Do not thin charter headings, hook steel, or roof text in the four `.mdc` files.
No nested `AGENTS.md` under `shared/` (root file wins; adapters re-attached on every Read).
Do not copy `stop` into `hooks.cloud.json` until a cloud turn is seen to receive `followup_message`.
Do not add coverage/mutation/Sonar/Halstead tools to this Bash pack.
Do not remove the User Rules charter from the base pack unless Mario edits User Rules.

## Proof

- `bash tests/run.sh` — 304 PASS, 0 FAIL (2026-09-08; Git Bash + jq)
- `bash scripts/doctor.sh` — ALL CHECKS PASSED
- Live `~/.cursor` reinstalled via `Windows/install.ps1` (checksums match)

## Next

Charter/always-on reduction and core/fleet split stay out of scope unless Mario edits User Rules. Observe failClosed + merge install in a real Cursor session.

## Archived

2026-09-07: 272 PASS; factory local; Windows Git Bash + jq.
2026-09-06: full pack lean. Tests 266 PASS.

<!-- COMPACTION PROTOCOL
When the active sections above (before this line) exceed ~150 lines:
1. Move older Now/Proof into Archived.
2. Keep Now, State, Limits, Proof, Next current.
3. Delete Archived older than the last 2 sessions.
4. Active section stays under ~150 lines.

session_start.sh points at this file (path only). Read Now, State, Limits, Proof, and Next.
Update this file only when state meaningfully changes.
-->