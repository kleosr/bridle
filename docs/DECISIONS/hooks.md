# Hooks (ADR)

Status: Accepted. Four registered events. Law stays in `.mdc`. Fleet does not rewrite other repos' hooks.

Four hooks enforce **documented restrictions on supported Cursor event paths**. Repository permissions, sandboxing, CI, and human authorization enforce the broader security boundary. Regex gates are substring heuristics, not a shell parser or sandbox.

| Script | Event | Job |
|--------|-------|-----|
| `before_submit_prompt.sh` | beforeSubmitPrompt | Secret-prompt block (`continue`; `failClosed:true`) |
| `before_shell.sh` | beforeShellExecution | Destructive / source-write / lint-disable / secret-path deny; infra/DB + activation ask (`failClosed:true`) |
| `before_read_file.sh` | beforeReadFile | Secret path deny (`failClosed:true`) |
| `stop.sh` | stop | Rewrite / format_churn / syntax-red followup (`loop_limit:1`, advisory; `failClosed:false`) |

## Coverage (claimed vs remaining)

| Protected action | Entry points covered | Decision | Remaining boundary |
|---|---|---|---|
| Read sensitive file | `beforeReadFile` (`file_path` / nested `tool_input`) | Deny | OS permissions / sandbox; Shell `cat` of the same path is a **different** event (`beforeShellExecution`); `Write`/`StrReplace`/MCP/Tab uncovered |
| Execute destructive command | `beforeShellExecution`, evaluated **per segment** | Deny | Execution permissions; interpreters, repo scripts, package lifecycle, encoded args, non-Shell tools |
| Commit-message false positives | `-m/--message/--title/--body/--notes` argument only | Allow inside that argument | Unquoted multi-word message values stay visible (fail-closed) |
| Change infrastructure | Recognized shell strings (`psql`, `terraform apply`, …) | Ask | Credentials / approval system; host pause unverified |
| Submit likely secret | `beforeSubmitPrompt` prompt fields | `continue:false` | Org-approved client/logging/telemetry; **hook timing vs remote submit is unverified** — do not claim the secret never left the machine |
| Edit source | Native Write/StrReplace **allowed**; Shell text-rewrite denied | Workflow restriction | Review / CI; not complete protection against source modification |
| Hook identity in shared files | Exact script basename (or the shim form) | Owned | Substring names (`my_stop.sh`) are foreign and survive merge/strip |

**Pass condition:** every claimed script guarantee has a fixture test and a stated limit in this table. Host enforcement of those JSON decisions is a separate, manual check (`SECURITY.md`).

## Failure classes (scripts)

Preventive hooks (submit / shell / read): invalid input, missing policy, missing working `jq`, or non-string command → deny / `continue:false` (not silent allow). Diagnostics in `user_message` must not echo secrets or the raw command. stdout is JSON only. Stable `reason` codes: `deny`, `destructive`, `secret-path`, `source-write`, `lint-disable`, `malformed`, `missing-policy`, `missing-jq`, `ask-infra`, `activation`, `harness`. Timeout/crash: host `failClosed:true` **requests** deny; host interpretation is unverified.

`stop.sh`: advisory only; cannot prevent completion; malformed/`aborted`/`loop_count>0` → `{}`; its own failure must not loop (`loop_limit:1`).

Cloud: user `~/.cursor/hooks.json` does **not** load. Cloud sees project `.cursor/hooks.json` only (plus Enterprise team/dashboard hooks). `hooks.cloud.json` is **opt-in** project-hooks (submit / shell / read; no `stop`). This pack has no repo-level hooks. Matrix: `docs/host-capability.md`.

Bans: no `updated_input`; no kleos-gate; no pack Python; event hooks ≤80 LOC.

Policy SSOT: `secret_paths.ere`, `secret_tokens.ere`, `lib/shell_gate.sh`, `lib/diff_gate.sh`, `lib/verify_gate.sh`. Roofs: `core.mdc`. Host I/O: `lib/host.sh`.

Canonical config: `shared/hooks/hooks.json`. Ownership: `lib/hooks_json.jq` (exact basename).
