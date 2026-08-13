# Architecture: 5 Layers & Deterministic Containment

kleosrules V2 uses the 5 Layers framework. Layers nest; they do not replace each other. When something breaks, fix the layer whose unit failed.

| # | Layer | Unit | kleosrules Implementation |
|---|-------|------|---------------------------|
| 1 | Prompt | Input | User message. The model remembers nothing before this call. |
| 2 | Context | Window | `HANDOFF.md` tail 15 via `session_start.sh`. |
| 3 | Harness | Pass | Cursor + four Bash user hooks. Law lives in `.mdc` / skills. |
| 4 | Loop | Run | The agent follows INTENT in chat. Hooks do not police conversation. |
| 5 | Graph | Job | Local Markdown files (`HANDOFF.md`). |

## Preventive Amnesia

Cursor reasons in a window that dies. `HANDOFF.md` keeps what must survive. `session_start.sh` injects the HANDOFF tail so the next chat is not blank.

## Three channels (context engineering)

Law, state, and feedback must not share one dump.

1. **Law** — paste + user `~/.cursor/rules` alwaysApply/glob `.mdc` (once) + skills on-demand. Project `.cursor/rules` is types.mdc. Cloud `project-hooks` copies GLOBAL+SHARED. Do not re-inject ponytail at sessionStart.
2. **State** — `session_start.sh` injects HANDOFF tail (`additional_context`). Cloud has no sessionStart.
3. **Feedback** — the model sees tool results. No postToolUse scorecard is registered.

## Injection vs Declaration

1. **Injection (Layer 2):** `session_start.sh` injects HANDOFF tail through `additional_context`. `before_submit_prompt.sh` returns `continue` (secret prompts may be `continue:false`). This pack does not register `preToolUse`, so it never emits `updated_input`.
2. **Declaration (Layer 1):** GROUND first (Grep/Glob/Read this codebase — do not invent paths). Then INTENT job card in **chat prose before Write** (never Shell/fence). That is law in `.mdc`, not a hook followup.
3. **Steel (Layer 3):** `before_shell.sh` denies a small destructive/source-write list (infra/DB is `ask`). `before_read_file.sh` denies secret paths. `beforeSubmitPrompt.failClosed` is false so a submit-hook crash cannot freeze chat.

## Runtime map

- **Muscles:** Four registered event hooks under `/shared/hooks` (max 80 LOC each; macOS + Linux + WSL userland). Unregistered conversation/lean/grounding scripts are gone.
- **Policy (wired):** `policy/secret_paths.ere` (`before_read_file.sh` via `grep -f`). Destructive/source-write is inline in `shell_gate.sh`.
- **Law (shared core):** `shared/rules/` (canonical .mdc + paste), `shared/skills/`, `shared/config/` (fleet scan roots, retire lists). Install: GLOBAL → `~/.cursor/rules`; SHARED → project `.cursor/rules`; cloud copies both.
- **Platforms:** `MacOS/install.sh`, `Linux/install.sh`, `Windows/install.ps1` + `Windows/hooks/wsl-shim.ps1`. Canonical hooks are POSIX bash in `shared/hooks/`.
- **Brain:** `HANDOFF.md` (local, always works).
- **State:** Ephemeral files in `/state/` (gitignored).
- **Registration (single GLOBAL layer):** user hooks live in `~/.cursor/hooks.json`. Commands are native `./hooks/*.sh` (cwd is `~/.cursor`). `fleet_sync.sh install` copies `hooks.json` unchanged. `sync`/`all` do **not** copy or delete other repos’ `.cursor/hooks`. Cloud: `CLOUD=1 TARGET_REPO=path … project-hooks` writes `hooks.cloud.json` into that repo only (no sessionStart; TARGET_REPO required; never the pack).

## Steel vs ask

- **deny:** destructive Shell and source-write (`shell_gate.sh` inline regex), secret paths (`policy/secret_paths.ere`).
- **ask:** infra/DB mutation (`terraform apply`, `kubectl delete`, `psql`, …) — Cursor approval card, not a silent deny.
- **Read secrets:** `before_read_file.sh` (`failClosed: true`).
- **Ungrounded Write / lean roofs / stop followups:** law in `.mdc`. Not registered events.
