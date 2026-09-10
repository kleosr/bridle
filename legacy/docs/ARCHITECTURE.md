# Architecture

Five layers. Fix the layer that failed.

| # | Layer | Unit | Here |
|---|---|---|---|
| 1 | Prompt | Input | User message |
| 2 | Context | Window | Project docs, config, Git, tests |
| 3 | Harness | Pass | Four Bash hooks on supported events. Law in `.mdc` / skills. Broader security: OS, CI, human auth |
| 4 | Loop | Run | Agent states the job in chat |
| 5 | Graph | Job | Git, `docs/`, `SECURITY.md` |

## Channels

1. **Law** — paste + `~/.cursor/rules` alwaysApply/glob `.mdc` + skills on demand. `SHARED=()`. Hooks never inject `.mdc`.
2. **State** — project docs, config, Git, tests. Do not invent state.
3. **Feedback** — tool results. `stop.sh`: one advisory `followup_message` on churn (diff added+deleted ≥50% vs HEAD, file ≥80 LOC) or mass reindent. Baseline is HEAD; attribution uncertain.

## Injection vs declaration

- Inject: nothing automatic. `beforeSubmitPrompt` → `continue` (secret → false). No `preToolUse`, no `updated_input`.
- Declare: open the files you will change. Concise output is a style default (outcome, files, verification); expand for architecture, risks, failures, or asked analysis.
- Steel (scripts): four hooks enforce documented restrictions on **supported Cursor event paths**. Broader security: repo permissions, sandboxing, CI, human authorization. Scripts emit deny/`continue:false` on match, malformed input, missing policy, or missing `jq`; deny > ask > allow. Shell screening is substring/regex heuristics, not parsing or containment. Source-write deny is a **workflow** restriction (hand-written edits via Write/StrReplace). Host `failClosed:true` requests blocking on hook failure; timing/pause unverified (`SECURITY.md`). Other channels are outside the boundary.

## Runtime

Event hooks ≤80 LOC in `shared/hooks/`. Policy in `lib/` + `policy/*.ere`. Install: GLOBAL `.mdc` → `~/.cursor/rules`. Platforms: `MacOS/`, `Linux/`, `Windows/` (Git Bash shim; WSL fallback). Registration: `~/.cursor/hooks.json`, commands `./hooks/*.sh` (Windows: rewritten to Git Bash shim).

## Steel vs ask

- **deny:** destructive Shell, source-write, cyclo-lint disable, sensitive-path screening (Read + Shell; `git commit` / `gh pr|issue` skip path scan).
- **ask:** infra/DB mutation; harness activation. Material command changes need renewed approval.
- **stop:** one advisory followup, `loop_limit: 1`. Cannot refuse completion. Not file size or complexity.
- **law only:** ungrounded Write, ladder, nesting. Loop: `docs/engineering-system.md`.

## Coverage

- Verified here (unit-tested): script allow/deny/ask/advisory outputs, malformed input, missing policy/`jq`, timeout-shape fallback to deny/`continue:false` in scripts. See `tests/`.
- Host: `docs/host-capability.md` (lanes + last live check). 2026-09-10 local: Shell deny before side effects observed; `ask` pause not observed; native Read of a `.env` path returned contents despite script deny; prompt-scan-before-transmit and `failClosed` crash path not run. Glob auto-activation timing still unverified.
- Uncovered: native `Write`/`StrReplace` of secret paths, MCP tools, Tab, alternate execution paths, allowed-program behavior, subagent host bypasses. Law only; do not rely on hooks for these.
