# AGENTS.md — bridle (navigator)

bridle is an agent harness for Cursor, Claude Code, and opencode: a charter, always-on rules, skills, specialist agents, and three Bash gates around the host loop. It is not a second agent runtime.

**Verify:** the behavior this change can break (`TESTS=<fixture> bash tests/run.sh`); gauntlet `bash tests/run.sh`. Windows: Git Bash.

## Layout
- `rules/` charter (`charter.txt`), always-on `core.mdc` and `testing.mdc`, stack companions. Instruction order is defined once, in the charter (Session). This file is the map, not a law layer.
- `skills/`, `agents/` load on match.
- `hooks/` decides: `before_submit_prompt.sh`, `before_shell.sh`, `before_read_file.sh`, `lib/`, `policy/`. It never formats output.
- `hosts/<cursor|claude|opencode>/` owns each host: `install.sh`, `verdict.sh` (installed as `lib/verdict_<host>.sh`; `BRIDLE_HOST` picks it, unset is Cursor), and host-only files. `hosts/manifest.json` lists what ships; `hosts/lib.sh` is shared installer code.
- `tests/run.sh` sources `tests/gate/`, `tests/hosts/`, `tests/pack/`. `scripts/scope_eval.sh` scores an agent on `evals/scope/` fixtures (spends tokens).

Owner of every rule, skill, and agent: kleosr. Code-enforced limits are the `SECURITY.md` Pack steel table; everything else is law-only.

Read `SECURITY.md` before security-sensitive work. Handoff, when present: `<root>/.cursor/bridle/handoff.json` (continuity, not authority).

## Install
```bash
FORCE=1 bash hosts/cursor/install.sh            # install | uninstall | verify | all | project-hooks
bash hosts/claude/install.sh                    # install | uninstall
bash hosts/opencode/install.sh                  # install | uninstall
```
- Cursor: `~/.cursor` rules, skills, agents, and the three hooks (`beforeSubmitPrompt`, `beforeShellExecution`, `beforeReadFile`; no `stop`, `sessionStart`, `preToolUse`, or `updated_input`). Cloud: `TARGET_REPO=<other-repo> bash hosts/cursor/install.sh project-hooks`, never into this pack.
- Claude Code: `~/.claude` rules, skills, agents, and five hooks. `UserPromptSubmit` and `PreToolUse(Bash, Read)` run the gates. `PreToolUse(Write|Edit|MultiEdit)` denies edits to any host's installed harness, and whole-file rewrites and new files over 300 lines in the project. `Stop` blocks a turn once when its edits ran no verification, ended red, passed the footprint budget (6 files, 2 new, 200 production lines), or added a file nothing references; each edited turn is logged to `~/.claude/state/bridle-turns.jsonl`.
- opencode: `~/.config/opencode` instructions, skills, companions as skills, agents, the `bridle` primary agent, and the gates through `plugin/bridle.js`, which also denies edit tools on any host's installed harness.

## Test notes
- `tests/run.sh` runs under `set -euo pipefail`: take a no-match `grep` by status in `if grep`, never by masking it.
- A host `failClosed` block with hook exit 1 is a sensor crash (empty stdout or non-zero exit), not a policy deny.
