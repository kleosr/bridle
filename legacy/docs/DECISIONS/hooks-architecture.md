# Hooks Architecture (ADR)

Status: Accepted. Changelog: `docs/_archive/hooks-architecture-2026-09.md`.

Four registered events. Law stays in `.mdc`. Fleet does not rewrite other repos' hooks.

Four hooks enforce **documented restrictions on supported Cursor event paths**. Repository permissions, sandboxing, CI, and human authorization enforce the broader security boundary. Regex gates are substring heuristics, not a shell parser or sandbox.

| Script | Event | Job |
|--------|-------|-----|
| `before_submit_prompt.sh` | beforeSubmitPrompt | Secret-prompt block (`continue`; `failClosed: true`) |
| `before_shell.sh` | beforeShellExecution | Destructive / source-write deny; infra/DB ask (`failClosed: true`) |
| `before_read_file.sh` | beforeReadFile | Secret path deny (`failClosed: true`) |
| `stop.sh` | stop | Rewrite / format_churn followup (`loop_limit: 1`, advisory; `failClosed: false`) |

## Coverage (claimed vs remaining)

| Protected action | Entry points covered | Decision | Remaining boundary |
|---|---|---|---|
| Read sensitive file | `beforeReadFile` (`file_path` / nested `tool_input`) | Deny | OS permissions / sandbox; Shell `cat` of the same path is a **different** event (`beforeShellExecution`); `Write`/`StrReplace`/MCP/Tab uncovered |
| Execute destructive command | `beforeShellExecution` string `command` | Deny | Execution permissions; interpreters, repo scripts, package lifecycle, encoded args, non-Shell tools |
| Change infrastructure | Recognized shell strings (`psql`, `terraform apply`, …) | Ask | Credentials / approval system; host pause not observed 2026-09-10 (`docs/host-capability.md`) |
| Submit likely secret | `beforeSubmitPrompt` prompt fields | `continue: false` | Org-approved client/logging/telemetry; **hook timing vs remote submit is unverified** — do not claim the secret never left the machine |
| Edit source | Native Write/StrReplace **allowed**; Shell text-rewrite denied | Workflow restriction | Review / CI; not complete protection against source modification |

**Pass condition:** every claimed script guarantee has a fixture test and a stated limit in this table. Host enforcement of those JSON decisions is a separate, manual check (`SECURITY.md`).

## Failure classes (scripts)

Preventive hooks (submit / shell / read): invalid input, missing policy, missing working `jq`, or non-string command → deny / `continue: false` (not silent allow). Diagnostics in `user_message` must not echo secrets or the raw command. stdout is JSON only. Optional `reason` is a stable code (`deny`, `destructive`, `secret-path`, `source-write`, `lint-disable`, `malformed`, `missing-policy`, `missing-jq`, `ask-infra`, `activation`). Timeout/crash: host `failClosed:true` **requests** deny; host interpretation is unverified.

`stop.sh`: advisory only; cannot prevent completion; malformed/`aborted`/`loop_count>0` → `{}`; its own failure must not loop (`loop_limit: 1`).

`ask` is useful only if the client pauses for authorization — test in a live session; do not assume. 2026-09-10 local check: script `ask` for `psql` did not pause (`docs/host-capability.md`).

Cloud: user `~/.cursor/hooks.json` does **not** load. Cloud sees project `.cursor/hooks.json` only (plus Enterprise team/dashboard hooks). `hooks.cloud.json` is **opt-in** project-hooks (submit / shell / read; no `stop`). This pack has no repo-level hooks. Matrix: `docs/host-capability.md`.

Bans: no `updated_input`; no kleos-gate; no pack Python; event hooks ≤80 LOC.

Policy SSOT: `secret_paths.ere`, `secret_tokens.ere`, `lib/shell_gate.sh`, `lib/diff_gate.sh`. Roofs: `ponytail.mdc`.

Canonical config: `shared/hooks/hooks.json`. Windows `install.ps1` rewrites commands to the Git Bash shim (WSL fallback) and copies the same four scripts + runtime libs as `fleet_install.sh`.

## Bounded shell matching

`shell_gate.sh` understands a **bounded** set of command-string forms (literal tokens, common flags, some pipelines/redirection via regex). It does not fully interpret quoting, subshells, wrappers, or dynamic construction. Ambiguous execution is not treated as fully parsed. Stronger guarantees require OS sandboxing and least privilege, not more regex.
