# NOW.md

## Now

Engineering-rules audit landed (`docs/engineering-rules-audit.md`, `docs/engineering-rules-decision.md`). One `AGENTS.md`, no `CLAUDE.md` (no consumer). Hooks fail safe on unreadable input and write nothing to disk. `bash scripts/uninstall.sh` exists.

Identity is User Rules charter plus Cursor + Grok lock. Specialists: hunter, cut, prove.

## State

Four events. Local `~/.cursor` install. `scan.roots` empty. No preToolUse. No `state/`.
Removed 2026-09-03: nested `AGENTS.md` adapters, `lib/shell_fleet.sh`, `tests/conversation_state.sh`.

## Limits

Never Lane-A into this pack. No `updated_input`. Secrets never in this file, chat, or paste.
Do not invent a new rule system. Do not thin the charter. Edit books only in this repo.

## Proof

2026-09-03, Linux runner (macOS via CI only; Windows/WSL untested):
- `bash tests/run.sh` — exit 0, 175 PASS / 0 FAIL
- `HOME=<tmp> FORCE=1 bash scripts/install.sh` ×2 — exit 0 both; `~/.cursor` tree identical
- `HOME=<tmp> bash shared/hooks/fleet_sync.sh verify` — exit 0, `[ok] verify smoke`
- `HOME=<tmp> bash scripts/doctor.sh` — exit 0, ALL CHECKS PASSED (76 ok)
- `HOME=<tmp> bash scripts/uninstall.sh` — exit 0; only empty `agents/ rules/ skills/` dirs remain
- `git diff --check` — exit 0; tree clean after tests

## Next

Re-run `FORCE=1 bash scripts/install.sh` on the real machine to drop `shell_fleet.sh` from `~/.cursor/hooks/lib`; delete any leftover `state/` dirs. Paste charter if not already done.

## Archived

2026-08-28: local pack, vernacular retired, hunter/cut/prove; 122 PASS baseline.

<!-- COMPACTION PROTOCOL
When the active sections above (before this line) exceed ~150 lines:
1. Move older Now/Proof into Archived.
2. Keep Now, State, Limits, Proof, Next current.
3. Delete Archived older than the last 2 sessions.
4. Active section stays under ~150 lines.

session_start.sh injects Now, State, Limits, Proof, and Next.
Update this file only when state meaningfully changes.
-->
