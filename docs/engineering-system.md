# Engineering System — GROUND → BOUND → PLAN → CHANGE → VERIFY → REVIEW → STOP

One loop, seven stages, each owned by the lightest mechanism that reliably performs it. Nothing is stated in two canonical layers; a later layer may verify an earlier one. Evidence: `docs/runtime-grounding-audit.md`.

## Stage ownership

| stage | job | owner mechanism | layer type | when it runs | failure behavior |
|---|---|---|---|---|---|
| GROUND | smallest correct repo/dir/task/state context | `session_start.sh` → `additional_context` (NOW.md Now/State/Limits/Proof/Next, ≤40 lines); Cursor rules engine loads 5 alwaysApply `.mdc` once; glob `.mdc` on path match; nested `AGENTS.md` on Read | hook (state) + rule (law) | session start / on Read | no NOW.md → `{}`; token blob → `{}`; plan mode → `{}` |
| BOUND | scope, protected paths, allowed ops, validation commands, hard stops | `before_read_file.sh` (secret paths, failClosed) · `before_shell.sh`/`shell_gate.sh` (destructive deny, source-write deny, complexity-lint-disable deny, secret-path deny, infra/DB ask) · `SECURITY.md` (SSOT text) | hook (steel) + canonical file | before every Read / Shell | deny/ask JSON with `user_message`; hook crash on shell = fail-open, on read = fail-closed |
| PLAN | smallest coherent change + tests; risk without speculative architecture | `agent.mdc` "Before you write" (one or two sentences: outcome, files, proof) · `ponytail.mdc` ladder · `complexity.mdc` cap | rule | before Write | judgment; not hook-enforced (no `preToolUse` by decision) |
| CHANGE | surgical complete edits | agent Write/StrReplace · `before_shell.sh` denies Shell writes to source so edits go through tool diffs | tool + hook | during turn | Shell source-write → `LEAN BYPASS BLOCK` |
| VERIFY | focused tests then repo validation, exact exit codes | `bash tests/run.sh` · `bash scripts/doctor.sh` · `prove` subagent for independent re-run | tests + on-demand agent | before "done" | `[fail]` lines name the test; doctor names the missing file and the recovery command |
| REVIEW | diff correctness, security, complexity, scope drift, duplication, Ponytail | `hunter` (security) · `cut` (simplicity) · `complexity` skill · `ponytail` skill | on-demand skills/agents | when invoked | judgment |
| STOP | refuse completion if checks failed or evidence missing; else concise proof | `stop.sh` + `lib/diff_gate.sh`: unrequested rewrite of a tracked file (>50% lines changed, ≥80 LOC) or mass reindent (whitespace-only churn) → one `followup_message` (`loop_limit: 1`) · agent cites green command + updates NOW.md (`agent.mdc`) | hook (deterministic subset) + rule (report) | after each completed turn | platform cannot refuse completion; hook re-prompts once; second pass is quiet |

## Precedence

1. Hook deny/ask (steel) beats any instruction. Never fight a deny.
2. User Rules charter (`USER-RULES.paste.txt`) is the floor; `agent.mdc` is the operational capsule; they list the same five events but only the capsule holds the harness table.
3. `.mdc` law beats `NOW.md` state. NOW.md is context, not authority.
4. Skills and subagents are vertical: read or invoke on match; never auto-injected.
5. `AGENTS.md` is handbook/navigation. Law is hooks + paste + `.mdc`.

## What loads, and why (new-engineer view)

| you open Cursor on a repo | loads | because |
|---|---|---|
| any repo | `agent.mdc`, `ponytail.mdc`, `pnpm.mdc`, `complexity.mdc`, `vibe.mdc` | `alwaysApply: true` in `~/.cursor/rules`; vibe is silent without `package.json` |
| any repo | User Rules charter | pasted once in Settings |
| repo with `NOW.md` | its Now/State/Limits/Proof/Next | `session_start.sh` |
| repo with `AGENTS.md` | root file; nested ones when you Read in that dir | Cursor workspace instructions (may lag disk until new chat) |
| edit `*.ts` | `types.mdc` (project) | glob |
| edit `tests/**` | `testing.mdc` | glob |
| never automatically | any `SKILL.md`, hunter/cut/prove | on demand only |
| each Shell / Read | `before_shell.sh` / `before_read_file.sh` | registered events |
| each completed turn | `stop.sh` | registered event; `{}` unless a roof is broken |

## Failure messages

| gate | message prefix | recovery named |
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

`FORCE=1 bash scripts/install.sh` twice → same 5 events, same script count, no duplicate basenames. `bash scripts/uninstall.sh` removes `hooks.json`, `hooks/`, owned `.mdc`, owned skills, agents; preserves unrelated files; second run is a no-op. Re-install after uninstall registers hooks. All in `tests/install_lifecycle.sh` (18 assertions, isolated `HOME`).

## Hard stops

No `updated_input` (no `preToolUse`). No Rust or pack Python. No MCP core dependency. Event hooks ≤80 LOC (`stop.sh` 16, `diff_gate.sh` 69 in lib). BSD grep/sed only. No secrets in NOW.md, paste, hooks, chat. `stop` never writes files, never parses conversation, never emits on `aborted`/`error`, never emits when `loop_count > 0`.

## Not in scope (by decision)

Judgment roofs (needless abstraction, speculative architecture, unused deps) stay with `cut` and the ponytail skill. `stop` on cloud agents is unregistered until verified. Precedence between two alwaysApply rules is not observable on this platform; the pack guarantees no two rules share a canonical heading instead.
