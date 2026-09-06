# Architecture

Five layers. Fix the layer that failed.

| # | Layer | Unit | Here |
|---|---|---|---|
| 1 | Prompt | Input | User message |
| 2 | Context | Window | Path to `NOW.md` (`session_start.sh`) |
| 3 | Harness | Pass | Five Bash hooks. Law in `.mdc` / skills |
| 4 | Loop | Run | Agent states the job in chat |
| 5 | Graph | Job | `NOW.md`, `SECURITY.md` |

## Channels

1. **Law** — paste + `~/.cursor/rules` alwaysApply/glob `.mdc` + skills on demand. `SHARED=()`. Hooks never inject `.mdc`.
2. **State** — `session_start.sh` points at NOW.md. Read it. Do not invent state.
3. **Feedback** — tool results. `stop.sh`: one `followup_message` on rewrite (>50% of a tracked file, ≥80 LOC) or mass reindent.

## Injection vs declaration

- Inject: path to NOW.md. `beforeSubmitPrompt` → `continue` (secret → false). No `preToolUse`, no `updated_input`.
- Declare: open the files you will change. One or two sentences: outcome, files, proof.
- Steel: `before_shell.sh` deny destructive/source-write/lint-disable/secret paths; infra/DB `ask`. `before_read_file.sh` deny secret paths (`failClosed: true`).

## Runtime

Event hooks ≤80 LOC in `shared/hooks/`. Policy in `lib/` + `policy/*.ere`. Install: GLOBAL `.mdc` → `~/.cursor/rules`. Platforms: `MacOS/`, `Linux/`, `Windows/` (WSL shim). Registration: `~/.cursor/hooks.json`, commands `./hooks/*.sh`. `sync` is opt-in.

## Steel vs ask

- **deny:** destructive Shell, source-write, cyclo-lint disable, secret paths (Read + Shell; `git commit` / `gh pr|issue` skip path scan).
- **ask:** infra/DB mutation.
- **stop:** one followup, `loop_limit: 1`. Cannot refuse completion. Not file size or complexity.
- **law only:** ungrounded Write, ladder, nesting. Loop: `docs/engineering-system.md`.
