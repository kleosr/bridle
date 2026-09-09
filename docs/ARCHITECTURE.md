# Architecture

Five layers. Fix the layer that failed.

| # | Layer | Unit | Here |
|---|---|---|---|
| 1 | Prompt | Input | User message |
| 2 | Context | Window | Project docs, config, Git, tests |
| 3 | Harness | Pass | Four Bash hooks. Law in `.mdc` / skills |
| 4 | Loop | Run | Agent states the job in chat |
| 5 | Graph | Job | Handoff note, `SECURITY.md` |

## Channels

1. **Law** — paste + `~/.cursor/rules` alwaysApply/glob `.mdc` + skills on demand. `SHARED=()`. Hooks never inject `.mdc`.
2. **State** — project docs, config, Git, tests. Optional handoff note for unfinished work. Do not invent state.
3. **Feedback** — tool results. `stop.sh`: one advisory `followup_message` on churn (diff added+deleted ≥50% vs HEAD, file ≥80 LOC) or mass reindent. Baseline is HEAD; attribution uncertain.

## Injection vs declaration

- Inject: nothing automatic. `beforeSubmitPrompt` → `continue` (secret → false). No `preToolUse`, no `updated_input`.
- Declare: open the files you will change. Default 1–2 sentences: outcome, files, proof; expand for architecture, risks, or asked analysis.
- Steel: supported shell/submit/read checks fail closed (deny > ask > allow). Deny destructive/source-write/lint-disable/sensitive paths; infra/DB `ask`. Other channels and allowed-program behavior are outside the boundary.

## Runtime

Event hooks ≤80 LOC in `shared/hooks/`. Policy in `lib/` + `policy/*.ere`. Install: GLOBAL `.mdc` → `~/.cursor/rules`. Platforms: `MacOS/`, `Linux/`, `Windows/` (Git Bash shim; WSL fallback). Registration: `~/.cursor/hooks.json`, commands `./hooks/*.sh`.

## Steel vs ask

- **deny:** destructive Shell, source-write, cyclo-lint disable, sensitive-path screening (Read + Shell; `git commit` / `gh pr|issue` skip path scan).
- **ask:** infra/DB mutation; harness activation. Material command changes need renewed approval.
- **stop:** one advisory followup, `loop_limit: 1`. Cannot refuse completion. Not file size or complexity.
- **law only:** ungrounded Write, ladder, nesting. Loop: `docs/engineering-system.md`.
