# Architecture: 5 Layers & Deterministic Containment

kleosrules V2 uses the 5 Layers framework. Layers nest; they do not replace each other. When something breaks, fix the layer whose unit failed.

| # | Layer | Unit | kleosrules Implementation |
|---|-------|------|---------------------------|
| 1 | Prompt | Input | User message. The model remembers nothing before this call. |
| 2 | Context | Window | `NOW.md` active sections via `session_start.sh`. |
| 3 | Harness | Pass | Cursor + five Bash user hooks. Law lives in `.mdc` / skills. |
| 4 | Loop | Run | The agent states the job in chat. Hooks do not police conversation. |
| 5 | Graph | Job | Local Markdown files (`NOW.md`, `SECURITY.md`). |

## Preventive Amnesia

Cursor reasons in a window that dies. `NOW.md` keeps what must survive. `session_start.sh` injects the active sections so the next chat is not blank.

## Three channels (context engineering)

Law, state, and feedback must not share one dump.

1. **Law** — paste + user `~/.cursor/rules` alwaysApply/glob `.mdc` (once) + skills on-demand. Project `.cursor/rules` is types.mdc. Do not re-inject ponytail at sessionStart.
2. **State** — `session_start.sh` injects NOW.md active sections (`additional_context`).
3. **Feedback** — the model sees tool results. `stop.sh` adds one bounded `followup_message` when the working-tree diff shows unrequested rewrite (>50% of a tracked file changed) or mass reindent (whitespace-only churn). No postToolUse scorecard.

## Injection vs Declaration

1. **Injection (Layer 2):** `session_start.sh` injects NOW.md active sections through `additional_context`. `before_submit_prompt.sh` returns `continue` (secret prompts may be `continue:false`). This pack does not register `preToolUse`, so it never emits `updated_input`.
2. **Declaration (Layer 1):** GROUND first (Grep/Glob/Read this codebase — do not invent paths). Then one or two sentences in chat before Write (never Shell/fence). That is law in `.mdc`, not a hook followup.
3. **Steel (Layer 3):** `before_shell.sh` denies a small destructive/source-write list (infra/DB is `ask`). `before_read_file.sh` denies secret paths. `beforeSubmitPrompt.failClosed` is false so a submit-hook crash cannot freeze chat.

## Runtime map

- **Muscles:** Five registered event hooks under `/shared/hooks` (max 80 LOC each; macOS + Linux + WSL userland). Unregistered conversation/grounding scripts are gone.
- **Policy (wired):** `policy/secret_paths.ere` (`before_read_file.sh` via `grep -f`). Destructive/source-write is inline in `shell_gate.sh`. Ponytail diff roofs are inline in `lib/diff_gate.sh` (`stop.sh`).
- **Law (shared core):** `shared/rules/` (canonical .mdc + paste), `shared/skills/`, `shared/agents/`, `shared/config/`. Install: GLOBAL → `~/.cursor/rules`; SHARED → pack `.cursor/rules` (types only).
- **Platforms:** `MacOS/install.sh`, `Linux/install.sh`, `Windows/install.ps1` + `Windows/hooks/wsl-shim.ps1`. Canonical hooks are POSIX bash in `shared/hooks/`.
- **Brain:** `NOW.md` (local). Security: `SECURITY.md`.
- **State:** Ephemeral files in `/state/` (gitignored).
- **Registration (single GLOBAL layer):** user hooks live in `~/.cursor/hooks.json`. Commands are native `./hooks/*.sh` (cwd is `~/.cursor`). `fleet_sync.sh install` copies `hooks.json` unchanged. `sync` is opt-in (`scan.roots` empty by default) and does **not** copy or delete other repos’ `.cursor/hooks`.

## Steel vs ask

- **deny:** destructive Shell and source-write (`shell_gate.sh` inline regex), cyclomatic-lint disable, secret paths in Read **and** Shell (`policy/secret_paths.ere`; `git commit` / `gh pr|issue` skip secret-path scan so PR bodies do not false-hit).
- **ask:** infra/DB mutation (`terraform apply`, `kubectl delete`, `psql`, …) — Cursor approval card, not a silent deny.
- **Read secrets:** `before_read_file.sh` (`failClosed: true`).
- **stop (bounded):** `stop.sh` emits one `followup_message` per turn (`loop_limit: 1`) naming the gate, file, and fix; `{}` otherwise. It cannot refuse completion (platform contract). Detects: unrequested rewrite of a tracked file (>50% lines changed, file ≥80 LOC) and mass reindent (whitespace-only churn). Does not detect: file size, cyclomatic complexity, needless abstraction — those stay in `.mdc`/skill/`cut`.
- **Ungrounded Write / ladder / nesting / naming:** law in `.mdc`. Not registered events.
