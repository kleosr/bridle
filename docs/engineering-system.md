# Engineering System — GROUND → STOP

One loop. Snapshot: `docs/_archive/runtime-grounding-audit.md`.

## Stage ownership

| stage | job | owner | when | failure |
|---|---|---|---|---|
| GROUND | smallest repo/task/state | `session_start.sh` path to NOW.md; 7 alwaysApply; glob `.mdc`; root AGENTS.md | session start / Read | no NOW / token / plan → `{}` |
| BOUND | scope + steel | `before_read_file.sh` (secrets, failClosed); `before_shell.sh` (destructive / source-write / lint-disable / secret deny; infra/DB ask); `SECURITY.md` | every Read / Shell | deny/ask JSON; shell crash fail-open; read fail-closed |
| PLAN | smallest change + proof | paste / `agent.mdc` (open files; outcome, files, proof); `ponytail.mdc`; `complexity.mdc` | before Write | judgment; no `preToolUse` |
| CHANGE | surgical edits | Write/StrReplace; Shell source-write denied | during turn | `LEAN BYPASS BLOCK` |
| VERIFY | exact exit codes | `bash tests/run.sh`; `bash scripts/doctor.sh`; `prove` | before done | `[fail]` / doctor names recovery |
| REVIEW | security, simplicity, roofs | `hunter` `cut` complexity/ponytail skills | on demand | judgment |
| STOP | refuse "done" without proof | `stop.sh` + `diff_gate.sh`: rewrite (>50%, ≥80 LOC) or mass reindent → one `followup_message` (`loop_limit: 1`) | after turn | cannot refuse completion; second pass quiet |

## Precedence

1. Hook deny/ask beats any instruction. Never fight a deny.
2. Paste is the floor; `agent.mdc` holds the harness table.
3. `.mdc` law beats `NOW.md` state.
4. Skills and subagents on match only.
5. `AGENTS.md` is navigation.

## What loads

| surface | loads | why |
|---|---|---|
| any repo | 7 alwaysApply `.mdc` | `~/.cursor/rules` |
| any repo | User Rules charter | Settings paste |
| repo with NOW.md | path (Read on demand) | `session_start.sh` |
| this pack | root `AGENTS.md` | workspace instructions |
| `*.sql` / schema | `postgres.mdc` | glob |
| Next / Vite / Astro | matching glob `.mdc` | glob |
| never auto | SKILL.md, hunter/cut/prove | on demand |
| each Shell / Read | `before_shell.sh` / `before_read_file.sh` | registered |
| each completed turn | `stop.sh` | `{}` unless a roof is broken |

## Failure messages

| gate | message prefix | recovery |
|---|---|---|
| destructive shell | `AUTONOMY BLOCK: destructive command denied` | — (stop) |
| shell source write | `LEAN BYPASS BLOCK: Shell must not create/overwrite source` | Use Write or StrReplace |
| complexity lint disable | `Do not disable cyclomatic lint from the shell` | Extract until lint green |
| secret path | `AUTONOMY BLOCK: shell/reading … blocked` | Read it yourself if needed |
| infra/DB | `Command mutates infra/DB` | Approve in the Cursor card |
| prompt token | `continue:false` + message | remove the token |
| stop rewrite | `rewrite: <file> changed N of M lines` | Touch only the hunk of the defect |
| stop format | `format_churn: <file> has N diff lines but only M are real` | Reindent is unrequested churn; revert to the hunk only |
| doctor drift | `live install missing/drift ~/.cursor/hooks/<file>` | `FORCE=1 bash scripts/install.sh` |

## Idempotency

`FORCE=1 bash scripts/install.sh` twice → same 5 events, same script count, no duplicate basenames. `bash scripts/uninstall.sh` removes `hooks.json`, `hooks/`, owned `.mdc`, owned skills, agents; preserves unrelated files; second run is a no-op. Re-install after uninstall registers hooks. All in `tests/install_lifecycle.sh` (isolated `HOME`).

## Hard stops

No `updated_input` (no `preToolUse`). No Rust or pack Python. No MCP core. Event hooks ≤80 LOC. BSD grep/sed only. No secrets in NOW.md, paste, hooks, chat. `stop` never writes files, never parses conversation, never emits on `aborted`/`error`, never emits when `loop_count > 0`.

## Not in scope

Judgment roofs stay with `cut` and the ponytail skill. `stop` on cloud is unregistered until verified. Two alwaysApply rules do not share a canonical heading.
