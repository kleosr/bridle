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
Source files: charter `shared/rules/charter.txt` (installed as `~/.cursor/rules/kleosr.mdc`), `shared/rules/*.mdc`, skills catalog `shared/catalog/skills.txt`. Instruction order is defined once, in the charter (Session). This file is the map, not a law layer.

## Pack verification
- Scoped: `TESTS=<fixture> bash tests/run.sh`. Gauntlet: `bash tests/run.sh`. Init does not run the suite.
- Feature pass-state: `bash scripts/feature.sh pass <id>` (records evidence for the current tree; a failure records `lastFailure.nextExperiment`). `bash scripts/feature.sh note <id> <hypothesis>` after diagnosis.
- Handoff: `bash scripts/handoff.sh write|check`.
- `tests/run.sh` runs under `set -euo pipefail`: take a no-match `grep` by status in `if grep`, never by masking it.
- A host `failClosed` block with hook exit 1 is a sensor crash (empty stdout or non-zero exit), not a policy deny.

## Config
- `shared/catalog/` is what ships (`manifest.json`, `skills.txt`, `rules.global.txt`, `retired*.txt`); `shared/config/` is the contract and ledger (`harness.json`, `features.json`).
- Extend via `shared/catalog/skills.txt` and glob companions.
- `evals/tasks.json` — structural coverage (`bash scripts/eval/check.sh check`). Live scoring is out of band: `bash scripts/eval/scope.sh run <id>` runs `$AGENT` on a fixture ask and scores production lines, verify, and wiring (spends tokens; the scorer itself: `TESTS=scope_eval bash tests/run.sh`).
- Hooks: three events (`beforeSubmitPrompt`, `beforeShellExecution`, `beforeReadFile`). No `stop`, no `sessionStart`, no `preToolUse`, no `updated_input`.

## Docs
`docs/architecture.md`, `docs/toolchain.md`, `docs/host-capability.md`.

## Install
```bash
FORCE=1 bash shared/hosts/cursor/install.sh
```
Uninstall: `bash shared/hosts/cursor/uninstall.sh`.
Claude Code: `bash shared/hosts/claude/install.sh install|uninstall` ports rules, skills, and agents into `~/.claude`, plus five hooks. `UserPromptSubmit`, `PreToolUse(Bash)`, and `PreToolUse(Read)` run the three `shared/gate/` scripts with `BRIDLE_HOST=claude` (verdict: `shared/hosts/claude/verdict.sh`; verify: `TESTS=claude_gates bash tests/run.sh`). `PreToolUse(Write)` (`shared/hosts/claude/before_write.sh`) denies whole-file rewrites and new files over 300 lines inside the project. `Stop` (`shared/hosts/claude/before_stop.sh`) blocks a turn once when its edits ran no verification, ended on a red verify, passed the footprint budget (6 files, 2 new, 200 production lines), or added a source file nothing references; every edited turn is logged to `~/.claude/state/bridle-turns.jsonl`, the data for retuning the budget. Verify: `TESTS=claude_stop bash tests/run.sh`. The Cursor three-event freeze is unaffected.
opencode: `bash shared/hosts/opencode/install.sh install|uninstall` ports rules (as `instructions`), skills, companions (as skills), agents, the `bridle` primary agent, and the three hooks (via `plugin/bridle.js`) into `~/.config/opencode`. Verify: `TESTS=opencode_port bash tests/run.sh`.
Cloud: `CLOUD=1 TARGET_REPO=<other-repo> bash shared/hosts/cursor/fleet_sync.sh project-hooks`. Never into this pack.

## Layout
`shared/gate/` decides (entry scripts, `lib/`, `policy/`) and never formats. `shared/hosts/<cursor|claude|opencode>/` owns each host's I/O: its `verdict.sh` (installed as `lib/verdict_<host>.sh`), registration, and `install.sh`. `BRIDLE_HOST` picks the verdict; unset is Cursor. `scripts/` is pack tooling only. `tests/run.sh` sources fixtures from `tests/gate/`, `tests/hosts/`, and `tests/pack/`; `TESTS=<fixture>` names stay the file basenames.
