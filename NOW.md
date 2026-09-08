# NOW.md

## Now

Session file is `NOW.md`. Security SSOT is `SECURITY.md`. Skill `/now`.
Caps live in `complexity.mdc` / `ponytail.mdc` / `testing.mdc` / `types.mdc`. Paste points at those files.
Ground the files you will change. Proof is the command this change can break.

## State

Five events: sessionStart, beforeSubmitPrompt, beforeShellExecution, beforeReadFile, stop. Local `~/.cursor` install. `scan.roots` empty. No preToolUse.
Always-on rules: agent, ponytail, pnpm, complexity, vibe, testing, types (7). Path-scoped: next, vite, astro, postgres.
`session_start.sh` points at NOW.md (path only). Token-like NOW → quiet. Plan mode → quiet.
`stop.sh` + `lib/diff_gate.sh`: unrequested rewrite (>50% of tracked src file, ≥80 LOC) + mass reindent + duplicate helper. One `followup_message`, `loop_limit: 1`. Cloud json unchanged (no stop).
`.env.example` readable. Token prefixes word-bounded. `beforeReadFile` denies missing policy / non-JSON.
Windows host is Git Bash + jq (`Windows/hooks/bash-shim.ps1`, UTF-8 stdin). WSL is fallback only. `scripts/install.sh` refuses MINGW.

## Limits

Never Lane-A into this pack. No `updated_input`. Secrets never in this file, chat, or paste.
Do not invent a new rule system. Do not thin charter headings, hook steel, or roof text in the four `.mdc` files.
No nested `AGENTS.md` under `shared/` (root file wins; adapters re-attached on every Read).
Do not copy `stop` into `hooks.cloud.json` until a cloud turn is seen to receive `followup_message`.
Do not add coverage/mutation/Sonar/Halstead tools to this Bash pack.

## Proof

- `bash tests/run.sh` — 272 PASS, 0 FAIL (2026-09-07; Git Bash + jq on this machine)
- `bash scripts/doctor.sh` — ALL CHECKS PASSED (live checksums match)
- `powershell -File Windows/install.ps1` — `[done] ... Windows via Git Bash + jq shim` (no WSL)
- Live `beforeReadFile` allowed `~/.cursor/hooks.json` through `bash-shim.ps1` (UTF-8 stdin)
- `winget install jqlang.jq` — jq 1.8.2 on this machine

## Next

This Cursor has a live global install (`~/.cursor` rules + skills + hunter/cut/prove + `/writing-pr` + five hooks). User Rules paste is still Settings-only.
Open: observe a positive glob-rule activation in a TS/JS repo; verify `stop` on cloud before adding it to `hooks.cloud.json`.
Open: observe a positive glob-rule activation in a TS/JS repo; verify `stop` on cloud before adding it to `hooks.cloud.json`.
GitHub repo description still says HANDOFF (API is read-only here).

## Archived

2026-09-06: full pack lean — skills/agents rewritten, docs/_archive, SOURCE.md, budget+install caps. Tests 266 PASS.
2026-09-05: Astra slim (AGENTS.md navigator). Then deleted nested `shared/*/AGENTS.md` + `docs/astra-slim.md`.

<!-- COMPACTION PROTOCOL
When the active sections above (before this line) exceed ~150 lines:
1. Move older Now/Proof into Archived.
2. Keep Now, State, Limits, Proof, Next current.
3. Delete Archived older than the last 2 sessions.
4. Active section stays under ~150 lines.

session_start.sh points at this file (path only). Read Now, State, Limits, Proof, and Next.
Update this file only when state meaningfully changes.
-->
