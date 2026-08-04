# Final Verification Report

Date: 2026-08-04
Session: Repository cleanup + hardening pass

## What was fixed

### Hooks architecture refactored
- `stop_gate.sh` (121 LOC) → thin wrapper (5 LOC) + `lib/stop_gate_core.sh`
- `pre_tool_use.sh` (109 LOC) → thin wrapper (5 LOC) + `lib/pre_tool_use_core.sh`
- `lean_gate.sh` upgraded with velocity check (edit-count per file per session)
- `lean_gate.sh` entropy check bug fixed (`wc -l` with `pipefail` producing `0\n0`)
- All event hooks now ≤80 LOC
- Shared utilities extracted to `hooks/lib/common.sh`
- All hooks source `common.sh` for root resolution + emit helpers

### Hook config consolidated
- Merged `hooks/hooks.json` + `hooks/hooks.project.json` into single canonical `hooks/hooks.json`
- Added `pre_tool_use.sh` to the hook registry (was missing)
- `fleet_sync.sh` now generates per-repo and home configs via jq path rewriting from the canonical source
- Deleted `hooks/hooks.project.json` (divergent duplicate)

### MCP-first → local-first
- README: Obsidian/MCP is now optional, not required
- AGENTS.md: "Brain equals HANDOFF.md (local)" — removed Obsidian as core
- All project-rules: vault_read/vault_write converted from hard requirement to optional
- user-rules paste: HANDOFF.md is the default brain; Obsidian optional
- hooks: vault write-back references replaced with HANDOFF update
- `stop_gate.sh` accept handler: seeds HANDOFF with bounded structure (no vault reference)

### HANDOFF.md expanded
- Full bounded structure: Active Objective, Current State, Constraints, Recent Verified Changes, Failed Attempts, Open Risks, Next Actions, Done-When, Archived
- Compaction protocol embedded (active ≤150 lines, archive older context)
- `session_start.sh` injects tail 15 lines

### Ponytail / lean gate strengthened
- LOC roof (700, hard) — unchanged, projected post-edit
- Entropy ceiling (30 flow-control keywords) — bug fixed
- Velocity check (15 edits/file/session) — new, prevents bloated-file patching

### Tests + doctor added
- `scripts/doctor.sh` — 16 environment + repo health checks
- `tests/run.sh` — 24 tests (syntax, JSON validity, hook fixtures)
- `tests/fixtures/` — 6 sample payloads for all hook events
- `scripts/install.sh` + `scripts/sync.sh` — thin wrappers to fleet_sync

## What was removed

| File | Reason |
|------|--------|
| `.cursor/hooks/policy/{ask-scope,context,delete,secrets,shell}.json` | Rust-gate remnants, never wired |
| `.cursor/v14-rule-inject.json` | V14 artifact, 2 major versions behind |
| `.cursor/breakthrough-chain.md` | Experimental scratch |
| `.cursor/breakthrough-research.md` | Experimental scratch |
| `.cursor/HANDOFF.md` | Stale sync-destination copy |
| `.cursor/state/*` | Ephemeral runtime state |
| `docs/evals/MINIMAL-NATIVE-EXPRESSION-AUDIT.md` | Audit of deleted Rust kleos-gate |
| `docs/evals/UNIFIED-COUNTEREXAMPLE-TAXONOMY.md` | Audit of deleted Rust kleos-gate |
| `hooks/hooks.project.json` | Divergent duplicate of hooks.json |

## What was refactored

| File | Change |
|------|--------|
| `hooks/stop_gate.sh` | 121→5 LOC wrapper, logic → lib |
| `hooks/pre_tool_use.sh` | 109→5 LOC wrapper, logic → lib |
| `hooks/lean_gate.sh` | Added velocity check, fixed entropy bug, uses common.sh |
| `hooks/before_submit_prompt.sh` | Uses common.sh, MCP→HANDOFF refs |
| `hooks/session_start.sh` | Uses common.sh, MCP→HANDOFF refs |
| `hooks/fleet_sync.sh` | jq-based config generation, copies lib/, removed hooks.project.json ref |
| All project-rules/*.mdc | MCP hard-dep → optional |
| user-rules/* | MCP hard-dep → optional |
| README.md | Full rewrite, local-first |
| AGENTS.md | MCP→local HANDOFF |
| docs/* | MCP→local, added doctor/test refs |
| package.json | Added scripts (doctor, test, sync, install), version bump |
| .github/workflows/gates.yml | Simplified to doctor + tests + fleet_sync |
| .gitignore | Added .kleos/ |

## What was verified

| Check | Evidence |
|-------|----------|
| All hooks pass `bash -n` | `tests/run.sh` syntax section: 10/10 pass |
| All JSON valid | `tests/run.sh` JSON section: 4/4 pass |
| Event hooks ≤80 LOC | `scripts/doctor.sh`: all 5 pass |
| lean_gate allows small writes | Fixture test: pass |
| lean_gate denies oversized writes | Smoke test: pass |
| pre_tool_use allows Read | Fixture test: pass |
| pre_tool_use blocks rm -rf / | Fixture test: pass |
| stop_gate followup on missing INTENT | Fixture test: pass |
| stop_gate accepts valid INTENT | Fixture test: pass |
| stop_gate ignores code-fence poison | Fixture test: pass |
| No Rust gate / updated_input | Doctor check: pass |
| No MCP core dependency in hooks | Doctor check: pass |
| HANDOFF has compaction protocol | Doctor check: pass |
| Wrappers source lib | Doctor check: pass |
| Policy count = 2 (intent + lean) | Doctor check: pass |
| Hook config references valid files | Doctor check: pass |
| .gitignore covers state/ + .cursor/ | Doctor check: pass |
| Total tests | **24 PASS / 0 FAIL** |
| Total doctor checks | **42 OK / 0 FAIL** |

## Known limitations

1. **Cursor hook API shape**: hooks validate stdin but rely on `messages`/`transcript`/`conversation` array shape for stop_gate. If Cursor changes the payload shape, the jq filters in `stop_gate_core.sh` need updating. The jq filter tries all three field names defensively.
2. **Shellcheck not installed locally**: CI installs it; local `tests/run.sh` skips if absent.
3. **Obsidian skills still reference MCP**: `skills/obsidian-memory/`, `skills/codebase-memory/`, `skills/session-handoff/` contain MCP references. These are optional on-demand skills — not core requirements. They work when MCP is configured.
4. **fleet_dispatch.sh** calls `claude -p` which requires Claude CLI installed. This is an optional tool, not a core hook.

## Recommended next steps

1. **Commit the changes** in logical atomic commits (hooks refactor, MCP removal, docs, tests).
2. **Run `FORCE=1 bash hooks/fleet_sync.sh all`** to sync the new structure to all fleet repos.
3. **Paste the updated `user-rules/USER-RULES.paste.txt`** into Cursor Settings → User Rules.
4. **Consider shellcheck in pre-commit** for continuous hook quality.
