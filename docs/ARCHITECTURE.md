# Architecture

Five layers. Fix the layer that failed. Machine-readable map: `shared/config/harness.json`.

| # | Layer | Unit | Here |
|---|---|---|---|
| 1 | Prompt | Input | User message |
| 2 | Context | Window | Project docs, `harness.json`, `features.json`, Git, tests |
| 3 | Harness | Pass | Four Bash hooks on supported events. Law in `.mdc` / skills. Init: `scripts/ready.sh`. Broader security: OS, CI, human auth |
| 4 | Loop | Run | Host owns it. Pack stopping conditions live in `harness.json` |
| 5 | Graph | Job | Git, `docs/`, `SECURITY.md`, feature list, optional handoff. Review nodes: `hunter` / `cut` / `prove` |

## Channels

1. **Law** — paste + `~/.cursor/rules` alwaysApply/glob `.mdc` + skills on demand. Hooks never inject `.mdc`. Always-on: `core.mdc`, `testing.mdc`.
2. **State** — `shared/config/features.json`, optional `state/handoff.json`, project docs, Git, tests. Feature/handoff files are continuity, not new authority.
3. **Feedback** — tool results. Treat as untrusted observations. `stop.sh`: one advisory `followup_message` on churn, mass reindent, shell/JSON syntax red, or `passing` without evidence. Baseline is HEAD; attribution uncertain. Does not execute repo test suites.

Usable context is smaller than the advertised window. Keep always-on law a map; load skills and topic docs on match. Durable state is Git + `docs/` + schema-validated feature/handoff files. The Cursor host owns the loop; this pack is the user harness (instructions + four hooks + contracts), not a second ReAct runtime.

Quality loop: understand → change → verify → correct. Verify is scoped by default (`harness.json` `verify.default`). Add a language, skill, or check through `plugins` / `extend` — do not add hook events.

## Injection vs declaration

- Inject: nothing automatic. `beforeSubmitPrompt` → `continue` (secret → false). No `preToolUse`, no `postToolUse`, no `updated_input`, no `sessionStart`.
- Declare: open the files you will change. Concise output is a style default (outcome, files, verification); expand for architecture, risks, failures, or asked analysis.
- Steel (scripts): four hooks enforce documented restrictions on **supported Cursor event paths**. Broader security: repo permissions, sandboxing, CI, human authorization. Scripts emit deny/`continue:false` on match, malformed input, missing policy, or missing working `jq`; deny > ask > allow. Shell screening splits the command into segments outside quotes and gates each segment; a `git commit`/`gh pr` message suppresses only its own argument. Source-write deny is a **workflow** restriction (hand-written edits via Write/StrReplace). Hook ownership is matched by exact script basename — names that merely contain a pack name are never owned. Host `failClosed:true` requests blocking on hook failure; timing/pause unverified (`SECURITY.md`). Other channels are outside the boundary.

## Runtime

Event hooks ≤80 LOC in `shared/hooks/`. Policy in `lib/` + `policy/*.ere`. Install: GLOBAL `.mdc` → `~/.cursor/rules`. Registration: `~/.cursor/hooks.json`, commands `./hooks/*.sh`. The pack checkout carries no `.cursor` layer; the cloud lane gets project hooks only (`hooks.cloud.json`, no `stop`).

Host adapter: `lib/host.sh` + `KLEOS_HOST=claude` maps deny/ask onto Claude Code `permissionDecision`. Default JSON stays Cursor `{permission}`. Portable law: `shared/hosts/CLAUDE.md`.

## Steel vs ask

- **deny:** destructive Shell, source-write, cyclo-lint disable, sensitive-path screening, harness self-modification (Read + Shell, per segment).
- **ask:** infra/DB mutation; harness activation (payload cwd, not hook cwd).
- **stop:** one advisory followup, `loop_limit:1`. Churn, mass reindent, new-file size roof, syntax red, or false feature `passing`. Cannot refuse completion. Does not execute repo test suites.
- **law only:** ungrounded Write, ladder, nesting. Write of `features.json` to `passing` is caught by `scripts/feature.sh check` / tests / stop advisory, not by a Write hook.

## Coverage

- Verified here (unit-tested): script allow/deny/ask/advisory outputs, malformed input, missing policy/`jq`, per-segment git/gh gating, exact-basename ownership, timeout-shape fallback to deny/`continue:false` in scripts, feature pass-state, lastFailure.nextExperiment, `feature.sh note` reflection, scoped feature evidence (no feature cites the bare gauntlet), handoff schema, ready/eval probes, scoped verify default, new-file size roof, invariants (no `preToolUse` / `NOW.md` / pack loop). See `tests/`.
- Host: `docs/host-capability.md` (lanes + last live check). Glob auto-activation timing still unverified.
- Uncovered: native `Write`/`StrReplace` of secret paths, MCP tools, Tab, alternate execution paths, allowed-program behavior, subagent host bypasses. Law only; do not rely on hooks for these.
