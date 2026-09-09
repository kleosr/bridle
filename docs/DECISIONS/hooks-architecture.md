# Hooks Architecture (ADR)

Status: Accepted. Changelog: `docs/_archive/hooks-architecture-2026-09.md`.

Four registered events. Law stays in `.mdc`. Fleet does not rewrite other repos' hooks.

| Script | Event | Job |
|--------|-------|-----|
| `before_submit_prompt.sh` | beforeSubmitPrompt | Secret-prompt block (`continue`; failClosed false) |
| `before_shell.sh` | beforeShellExecution | Destructive / source-write deny; infra/DB ask |
| `before_read_file.sh` | beforeReadFile | Secret path deny (`failClosed: true`) |
| `stop.sh` | stop | Rewrite / format_churn followup (`loop_limit: 1`) |

Cloud: `hooks.cloud.json` = submit / shell / read. No stop.

Bans: no `updated_input`; no kleos-gate; no pack Python; event hooks ≤80 LOC.

Policy SSOT: `secret_paths.ere`, `secret_tokens.ere`, `lib/shell_gate.sh`, `lib/diff_gate.sh`. Roofs: `ponytail.mdc`.

Canonical config: `shared/hooks/hooks.json`. Windows `install.ps1` rewrites commands to the Git Bash shim (WSL fallback) and copies the same four scripts + runtime libs as `fleet_install.sh`.
