# NOW.md

## Now

Session file is `NOW.md`. Security SSOT is `SECURITY.md`. Skill `/now`.

Hook audit done. `shell_gate.sh` rewritten: separators (`&&`, `;`, `|`) no longer bleed between commands; `rm -fr /`, `rm -rf "$HOME"`, `git push … -f`, `$(cat .env)`, `grep X .env`, `cat x.pem | …`, python heredoc source-write now deny. `.env.example` readable. Token regex word-bounded (`tomsk-…` passes). `head -n 150` matches compaction protocol. cwd diagnostic removed (answer: hooks run with cwd `~/.cursor`).

## State

Four events. Local `~/.cursor` install. `scan.roots` empty. No preToolUse.
Team book retired. Settings User Rules not readable from disk.
Known accepted false positives: `echo "… > x.ts"` inside quotes; `jq '.env'`; `git push --force-with-lease`; `git checkout -- a.ts` (intended).

## Limits

Never Lane-A into this pack. No `updated_input`. Secrets never in this file, chat, or paste.
Do not invent a new rule system. Do not thin the charter.
Cloud Agents, Tab, Inline Edit, Bugbot are out of scope.

## Proof

- `bash tests/run.sh` — 157 PASS (new `tests/gate_edges.sh`)
- `FORCE=1 bash scripts/install.sh` + `bash scripts/doctor.sh` — ALL CHECKS PASSED
- `docs/STEER-EVAL.md` — contaminated steer record
- `cmp` Downloads pastes == `shared/rules/USER-RULES.paste.txt`

## Next

Paste `shared/rules/USER-RULES.paste.txt` in Settings. Open this repo. New Grok 4.6 chat. Re-run the three prompts in `docs/STEER-EVAL.md`. Commit when asked.

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
