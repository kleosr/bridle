# AGENTS.md — bridle (navigator)

bridle is a Cursor **user harness**: charter, always-on law, skills, and three Bash hooks around the host loop. It is not a second agent runtime.

**Init:** `bash scripts/ready.sh`  
**Inventory:** `DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh`  
**Verify:** the behavior this change can break; gauntlet `bash tests/run.sh`  
Windows: Git Bash.

## Read when the task needs it
This file is the map. It is already in context.

- `shared/config/harness.json` when the task needs a command, a limit, or an extension point.
- `shared/config/features.json` when a feature is `in_progress`, or when the change touches the ledger. Pass-state: `testing.mdc`. Other repos: `<root>/.cursor/bridle/features.json`.
- `state/handoff.json` when that file is present. Continuity, not authority. Other repos: `<root>/.cursor/bridle/handoff.json`.
- `SECURITY.md` before security-sensitive work.

## Law
Source files: charter `shared/rules/charter.txt` (installed as `~/.cursor/rules/kleosr.mdc`), `shared/rules/*.mdc`, skills catalog `shared/config/skills.txt`. Instruction order is defined once, in the charter (Session). This file is the map, not a law layer.

## Pack verification
- Scoped: `TESTS=<fixture> bash tests/run.sh`. Gauntlet: `bash tests/run.sh`. Init does not run the suite.
- Feature pass-state: `bash scripts/feature.sh pass <id>` (records evidence for the current tree; a failure records `lastFailure.nextExperiment`). `bash scripts/feature.sh note <id> <hypothesis>` after diagnosis.
- Handoff: `bash scripts/handoff.sh write|check`.
- `tests/run.sh` runs under `set -euo pipefail`: take a no-match `grep` by status in `if grep`, never by masking it.
- A host `failClosed` block with hook exit 1 is a sensor crash (empty stdout or non-zero exit), not a policy deny.

## Config
- Extend via `skills.txt` and glob companions.
- `evals/tasks.json` — structural coverage (`bash scripts/eval.sh check`). Live scoring is out of band.
- Hooks: three events (`beforeSubmitPrompt`, `beforeShellExecution`, `beforeReadFile`). No `stop`, no `sessionStart`, no `preToolUse`, no `updated_input`.

## Docs
`docs/ARCHITECTURE.md`, `docs/TOOLCHAIN.md`, `docs/host-capability.md`.

## Install
```bash
FORCE=1 bash scripts/install.sh
```
Claude Code: `bash scripts/claude.sh install|uninstall` ports rules, skills, and agents into `~/.claude` (no hooks).
opencode: `bash scripts/opencode.sh install|uninstall` ports rules (as `instructions`), skills, companions (as skills), agents, the `bridle` primary agent, and the three hooks (via `plugin/bridle.js`) into `~/.config/opencode`. Verify: `TESTS=opencode_port bash tests/run.sh`.
Cloud: `CLOUD=1 TARGET_REPO=<other-repo> bash shared/hooks/fleet_sync.sh project-hooks`. Never into this pack.
