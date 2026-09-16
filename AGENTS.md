# AGENTS.md — bridle (navigator)

bridle is a Cursor **user harness**: charter, always-on law, skills, and four Bash hooks around the host loop. It is not a second agent runtime.

**Init:** `bash scripts/ready.sh`  
**Inventory:** `DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh`  
**Verify:** the behavior this change can break; gauntlet `bash tests/run.sh`  
Windows: Git Bash.

## First reads
1. This file.
2. `shared/config/harness.json` — runtime contract (commands, limits, extension points).
3. `shared/config/features.json` — one `in_progress`. Pass-state rules: `testing.mdc`. (Other repos: `<root>/.cursor/bridle/features.json`.)
4. `state/handoff.json` if present — continuity, not authority. (Other repos: `<root>/.cursor/bridle/handoff.json`.)
5. `SECURITY.md` before security-sensitive work.

## Law (priority order)
1. Charter: `shared/rules/USER-RULES.paste.txt` (installed as `~/.cursor/rules/kleosr.mdc`; not a Settings paste)
2. Boundary: `SECURITY.md` (read on demand; outranks on boundary questions)
3. Always-on: `core.mdc`, `testing.mdc`
4. Glob companions: host-attached on path; treat as inert when the owning package does not match
5. Skills on match: catalog `shared/config/skills.txt` (pack: `debugging`, `testing`, `handoff`; vendor UI/motion on match)
6. Specialists: `hunter` / `cut` / `prove` — invoke only

## Config
- Extend via `skills.txt` and glob companions.
- `evals/tasks.json` — structural coverage (`bash scripts/eval.sh check`). Live scoring is out of band.
- Hooks: four events. No `sessionStart`, no `preToolUse`, no `updated_input`.

## Docs
`docs/ARCHITECTURE.md`, `docs/TOOLCHAIN.md`, `docs/DECISIONS/hooks.md`, `docs/DECISIONS/engineering-os.md`, `docs/host-capability.md`.

## Install
```bash
FORCE=1 bash scripts/install.sh
```
Cloud: `CLOUD=1 TARGET_REPO=<other-repo> bash shared/hooks/fleet_sync.sh project-hooks`. Never into this pack.
