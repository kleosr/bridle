# Hooks Architecture Decision Record (ADR)

Date: 2026-08-12
Status: **Accepted (native cut; supersedes 2026-07-30 / 2026-08-11 Lane-A sprawl)**
Deciders: kleosr (system architect)
Context: Cursor user hooks are JSON stdio, cwd `~/.cursor`, native `./hooks/foo.sh`. Cookbook is ~4 scripts. failClosed default is false. Cloud sees project hooks only.

---

## Decision

**Four registered events. Law stays in `.mdc`. Fleet does not touch other repos’ hooks.**

| Script | Event | Job |
|--------|-------|-----|
| `session_start.sh` | sessionStart | Inject NOW.md active sections (`additional_context`) |
| `before_submit_prompt.sh` | beforeSubmitPrompt | Secret-prompt block via `continue` (`failClosed: false`) |
| `before_shell.sh` | beforeShellExecution | Destructive / source-write deny; infra/DB `ask` (`failClosed: false`) |
| `before_read_file.sh` | beforeReadFile | Secret path deny (`failClosed: true`) |

`fleet_sync.sh` copies `hooks.json` unchanged to `~/.cursor/hooks.json`. No jq path rewrite.

Cloud: `CLOUD=1 TARGET_REPO=path project-hooks` writes `hooks.cloud.json` (shell/read/submit, no sessionStart). TARGET_REPO required. Never the pack.

Deleted 2026-08-12: `stop_gate.sh`, `lean_gate.sh`, `pre_tool_use.sh`, scorecard, subagent, MCP, and their libs. They are not in `hooks.json` and not on disk.

Hard bans: never `updated_input`; never reintroduce `hooks/bin/kleos-gate` or pack Python; each registered event hook ≤80 LOC; no MCP core dependency; no GNU-only utils.

## Why not the 16-event harness

Conversation police (`stop_gate`), Read-before-Write grounding, and `lean_gate` failClosed denies fought cached/parallel Reads and locked chat on 127. Cursor already has permissions. Steel that remains is secrets + one shell deny list + NOW.md tail.

## Policy SSOT (wired only)

| File | Consumer |
|------|----------|
| `shared/hooks/policy/secret_paths.ere` | `before_read_file.sh`, `before_shell.sh` (`gate_shell_secrets`) |
| `shared/hooks/policy/secret_tokens.ere` | `before_submit_prompt.sh` |
| `shared/hooks/lib/shell_gate.sh` | `before_shell.sh` (inline destructive / source-write / infra ask) |

Roofs live in `ponytail.mdc`. No json policy.

## Hook config (canonical)

Single source: `shared/hooks/hooks.json`. User commands are `./hooks/*.sh`. Windows `install.ps1` still rewrites to the WSL shim.

**2026-08-12 — native cut.** Four events. Native paths. Fleet does not copy/delete other repos’ `.cursor/hooks`. `beforeSubmitPrompt.failClosed: false`. `beforeReadFile.failClosed: true`.

**2026-08-12 — law coherence.** alwaysApply `.mdc` install user-only (`GLOBAL`). Project layer is `types`. Cloud `project-hooks` copies GLOBAL+SHARED. Steel hooks are stateless (secrets + shell). Paste/skills describe those four events.

**2026-08-13 — audit fix.** Merged native-lean into `ponytail.mdc`. Retired `debugging.mdc` (skill only). Deleted unused `lean.json`, `intent.json`, `mcp_deny.ere`, `destructive.ere`, `vernacular_bans.txt` from hook policy.

**2026-08-27 — HANDOFF inject + INTENT voice.** `session_start.sh` sends named active sections, not a dumb last-15 tail (Objective lived at the top and was dropped). Law asks for one or two professional sentences before Write, not an `OBJECTIVE=` job card. `before_shell` ignores git/gh when scanning cyclomatic-lint bypass (PR bodies were false positives). Quiet only when `composer_mode` is `plan` — live Cursor Agent sends `chat`, which used to skip inject.

**2026-08-28 — NOW.md.** Session file is `NOW.md` (was HANDOFF.md). `SECURITY.md` is the pnpm + cyber SSOT. Skill `/now`.
