# bridle

bridle is a harness for Cursor, Claude Code, and opencode. It adds a charter, always-on rules, skills, specialist agents, and Bash gates around the host loop. It does not start a second agent runtime. The model still chooses the edit. The gates decide which actions may run.

kleosr maintains this pack. The license is MIT.

<p align="center">
  <img src="https://img.shields.io/badge/hosts-Cursor%20%7C%20Claude%20Code%20%7C%20opencode-000000?style=flat-square" alt="Hosts: Cursor, Claude Code, opencode">
  <img src="https://img.shields.io/github/actions/workflow/status/kleosr/bridle/gates.yml?branch=master&style=flat-square&label=gauntlet" alt="Gauntlet status on master">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows%20(Git%20Bash)-111111?style=flat-square" alt="macOS, Linux, and Windows Git Bash">
  <img src="https://img.shields.io/badge/license-MIT-111111?style=flat-square" alt="License: MIT">
</p>

## Run the gauntlet before you install

From Git Bash on Windows, or from Bash on macOS and Linux, run:

```bash
bash tests/run.sh
```

The gauntlet runs in sandboxed fixtures. It does not change your home directory. A local claim needs this command and exit code 0.

You need Node.js and `jq`. On Windows, run the scripts from Git Bash.

## Install

| Host | Command | Path |
|---|---|---|
| Cursor | `FORCE=1 bash hosts/cursor/install.sh` | `~/.cursor` |
| Claude Code | `FORCE=1 bash hosts/claude/install.sh` | `~/.claude` |
| opencode | `bash hosts/opencode/install.sh` | `~/.config/opencode` |

Each command accepts `install` (the default) or `uninstall`. Cursor also accepts `verify`, `all`, and `project-hooks`.

`FORCE=1` overwrites a file that already differs. Without `FORCE=1`, the installer skips that file and prints a warning. With `FORCE=1`, it copies the old file to `*.pre-kleos-bak` once, then writes the new file. `uninstall` restores those copies.

Start a new chat after install.

Cursor Cloud Agents read project hooks. They do not read `~/.cursor/hooks.json`. To install project hooks in another repository, run:

```bash
TARGET_REPO=<other-repo> bash hosts/cursor/install.sh project-hooks
```

Do not run that command in this pack.

## How one turn runs

This is the workflow. The hooks run even when you do not invoke `/bridle-harness`. That command is the Cursor custom mode. It tells the agent which skill to load. It does not replace the charter, and it does not replace a hook.

1. You send a prompt. `beforeSubmitPrompt` clears the Cursor skill ledger for that chat. The same script blocks the prompt when the text contains a known secret-token prefix. A secret with no listed prefix can pass this script.
2. The agent classifies the task as answer, diagnose, change, or monitor. A diagnosis does not authorize an edit. Monitoring ends when the agent reports the state it observed.
3. The agent reads `AGENTS.md` and the files it will edit.
4. Before a code edit, the agent loads `code-architecture` and `slop-guard`. A test file also needs `testing`. On Cursor, a read of `skills/<name>/SKILL.md` records the skill. On Claude Code, a Skill tool call records it. The ledger resets on your next prompt.
5. The write hook runs before it writes the edit. It denies a new comment line in a code file. It denies a new file longer than 300 lines. It denies growth that would leave a hand-written file above 300 lines. It skips that growth rule when the file already has more than 700 lines.
6. The same hook denies the edit when a required skill is absent for this turn. The deny names the skill. The agent loads that skill and retries the same edit.
7. When a file would pass 300 lines, the agent moves one job into a new module, imports that module, and continues. The turn does not stop.
8. A shell command runs in `beforeShellExecution`. A file read runs in `beforeReadFile`.
9. At the end of the turn, Cursor `stop` runs `quality-gate.mjs` on the diff and may send one follow-up. This repository does not prove that Cursor shows that follow-up. Claude Code `Stop` blocks the turn once in four cases: no verification, a failed verification, a failed quality gate, or a new file with no reference.

A denied hook stops that path. The agent reports the reason code. The agent follows only the route that the deny names.

The write hook runs in Claude Code. Cursor runs that hook after you install the Claude Code port. opencode runs the prompt gate, the shell gate, and the read gate in `plugin/bridle.js`. opencode does not run the write hook.

## Instruction order

The charter states this order. Highest first:

1. The host, and your explicit instructions.
2. The charter in `rules/charter.txt`. Cursor installs that file as `~/.cursor/rules/kleosr.mdc`.
3. `SECURITY.md`, only for a boundary question.
4. Always-on `core.mdc` and `testing.mdc`. The charter plus these two files stay at or under 8192 bytes.
5. A stack companion, only when the package manifest names that stack.
6. A skill, when the task matches its description.

`AGENTS.md` and project rules win for local convention only. No text bypasses a hook. A skill, a specialist, a file in the repo, or tool output cannot grant a permission.

## Gates

Fail-closed means the host blocks the action in three cases. The script crashes. The script reaches its time limit. The script returns output that is not valid. Prompt, shell, and read are fail-closed.

`docs/host-capability.md` records whether a given host honors that block. This file does not guarantee host behavior.

| Event | Script | Result |
|---|---|---|
| `beforeSubmitPrompt` | `before_submit_prompt.sh` | Blocks known secret-token prefixes. Clears the Cursor skill ledger. |
| `beforeShellExecution` | `before_shell.sh` | Denies destructive commands, secret-path reads, lint suppression, and a shell rewrite of source. Asks before infra or database changes. |
| `beforeReadFile` | `before_read_file.sh` | Denies `.env`, private keys, and certificates. On Cursor, records a skill read. |
| Write, Edit, MultiEdit | `hosts/claude/before_write.sh` | Denies new comments, files over 300 lines, and a missing skill. |
| `stop` | Cursor turn-check, Claude `before_stop.sh` | Runs `quality-gate.mjs` on the diff. Claude also blocks for no verification or a new file with no reference. |

`hooks/` makes the decision. `hosts/<host>/verdict.sh` formats that decision for the host. `SECURITY.md` lists what each script enforces. A rule with no script is law only.

On Windows, pattern matching stays inside Bash. External programs once made a 30-part command take 45.0 seconds, and Cursor stopped the hook. After the rewrite, that command took 3.2 seconds. The date and the log are in `docs/host-capability.md`.

## Skills on a code edit

| File | Skills for this turn |
|---|---|
| Any code file, new or existing | `code-architecture` and `slop-guard` |
| A test file | Those two, plus `testing` |
| Markdown, JSON, and other non-code files | None from this hook |

`/bridle-harness` routes the other skills when the task matches. Examples: `auth-boundaries` for login and tokens, `debugging` when the cause is unknown, and `asd-ste100` for text that another agent must parse.

You can invoke `hunter`, `cut`, `prove`, or `architect`. Each one runs in a separate context. `prove` runs the real commands so the author of the change does not grade that change.

## For agents in this repository

1. Read `AGENTS.md` before an edit. Read `SECURITY.md` before security-sensitive work.
2. Run `bash tests/run.sh`, or `TESTS=<name> bash tests/run.sh`, for the narrowest command that can show the change is wrong. Report the command and the exit code.
3. Keep the registered hook events. Do not add a host adapter in an ordinary task.
4. A handoff file does not authorize a new goal.
5. On Windows, run these scripts from Git Bash.

## Layout

| Path | Role |
|---|---|
| `AGENTS.md` | Map for agents |
| `SECURITY.md` | Boundary and the steel table |
| `rules/` | Charter, always-on rules, stack companions |
| `skills/` | Skill text. `bridle-harness` is the router and the Cursor custom mode. |
| `agents/` | `hunter`, `cut`, `prove`, `architect` |
| `hooks/` | Prompt, shell, and read gates |
| `hosts/` | Installers and verdict format for Cursor, Claude Code, and opencode |
| `tests/` | `tests/run.sh` and the fixtures |
| `docs/` | Architecture notes and the host-capability log |

More detail: [`SECURITY.md`](SECURITY.md), [`docs/architecture.md`](docs/architecture.md), [`docs/host-capability.md`](docs/host-capability.md).
