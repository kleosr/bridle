# AGENTS.md — bridle (navigator)

bridle is a Cursor **user harness**: charter, always-on law, skills, and four Bash hooks around the host loop. It is not a second agent runtime.

**Init:** `bash scripts/ready.sh`  
**Inventory:** `DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh`  
**Verify:** the behavior this change can break; gauntlet `bash tests/run.sh` 
**Completion:** `bash scripts/complete.sh check` (counts and signals; exit 0 act / 3 escalate); benchmark `bash scripts/bench.sh`  
Windows: Git Bash.

## Read when the task needs it
This file is the map. It is already in context.

- `shared/config/harness.json` when the task needs a command, a limit, or an extension point.
- `shared/config/features.json` when a feature is `in_progress`, or when the change touches the ledger. Pass-state: `testing.mdc`. Other repos: `<root>/.cursor/bridle/features.json`.
- `state/handoff.json` when that file is present. Continuity, not authority. Other repos: `<root>/.cursor/bridle/handoff.json`.
- `SECURITY.md` before security-sensitive work.

## Law (priority order)
1. Charter: `shared/rules/USER-RULES.paste.txt` (installed as `~/.cursor/rules/kleosr.mdc`; not a Settings paste)
2. Boundary: `SECURITY.md` (read on demand; outranks on boundary questions)
3. Always-on: `core.mdc`, `testing.mdc`
4. Glob companions: host-attached on path; treat as inert when the owning package does not match
5. Skills on match: catalog `shared/config/skills.txt` (pack: `kleosr` session router, `debugging`, `testing`, `handoff`; vendor UI/motion on match)
6. Specialists: `hunter` / `cut` / `prove` — invoke only

`kleosr` is a session router (`mode: true`, `disable-model-invocation: true`). This file is the map, not a law layer above `core.mdc` / `testing.mdc`.

## Config
- Extend via `skills.txt` and glob companions.
- `evals/tasks.json` — structural coverage (`bash scripts/eval.sh check`). Live scoring is out of band.
- Hooks: four events. No `sessionStart`, no `preToolUse`, no `updated_input`.

## Docs
`docs/ARCHITECTURE.md`, `docs/TOOLCHAIN.md`, `docs/DECISIONS/hooks.md`, `docs/DECISIONS/engineering-os.md`, `docs/DECISIONS/completion-gate.md`, `docs/DECISIONS/2026-09-18-instruction-hierarchy-audit.md`, `docs/host-capability.md`.

## Install
```bash
FORCE=1 bash scripts/install.sh
```
Cloud: `CLOUD=1 TARGET_REPO=<other-repo> bash shared/hooks/fleet_sync.sh project-hooks`. Never into this pack.
