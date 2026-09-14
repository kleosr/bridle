# Architecture

The host owns the model loop, tools, sandbox, conversation, and compaction. This pack is the engineering layer around that loop. It supplies context selection, durable contracts, deterministic boundary checks, verification discipline, and independent review without creating a second agent runtime.

## Contract

| Concern | Owner | Repository artifact |
|---|---|---|
| Repository map | Instructions | `AGENTS.md` |
| Runtime commands and invariants | Machine contract | `shared/config/harness.json` |
| Durable engineering law | Rules | `shared/rules/core.mdc`, `shared/rules/testing.mdc` |
| Framework/language guidance | Glob rules | `shared/rules/*.mdc` |
| Task-specific procedure | Skills on match | `shared/skills/` |
| Deterministic boundary checks | Hooks | `shared/hooks/` |
| Durable state and recovery | Git + contracts | `docs/`, `shared/config/features.json`, optional `state/handoff.json` |
| Independent review | Specialists | `shared/agents/` |

`shared/config/harness.json` contains only values the runtime reads: commands, limits, layers, required eval dimensions, and extension points. Philosophy and rationale stay in docs and rules.

## Context

Usable context is smaller than the advertised window. Start with `AGENTS.md`, then read the files this task can affect. Always-on rules remain a map. Skills and topic docs load only on match. Continuity files are evidence, not authority for new goals or approvals.

## Enforcement

Four hooks cover supported boundary events:

- `beforeSubmitPrompt`: block known secret/token patterns; fail closed.
- `beforeShellExecution`: deny destructive, secret-path, lint-disable, and shell source-write actions; ask for recognized infra mutations.
- `beforeReadFile`: deny sensitive paths; fail closed.
- `stop`: emit one non-blocking advisory for churn, format churn, syntax errors, size, or false feature `passing`.

Hook stdout is JSON. Scripts treat missing input, malformed payloads, missing policy, or an unavailable `jq` executable as failure. The host's handling of `failClosed`, `ask`, Read denies, and cloud lanes is recorded in `docs/host-capability.md`; it is not guaranteed by script tests.

## Verification

The loop is `understand -> change -> verify -> correct`. Verification is scoped by default. The narrowest check that can falsify the change runs first; repository-wide claims require the gauntlet. A feature becomes `passing` only through `scripts/feature.sh pass`, which records command, exit, and a proving artifact. The stop hook cannot replace a real run.

## Extension

Add a language rule to `shared/config/rules.global.txt`, a task skill to `shared/config/skills.txt`, or a verification command through the repository's existing toolchain. Do not add hook events, a pack-owned ReAct loop, session-start injection, or a parallel policy store.

Host adapter: `shared/hooks/lib/host.sh`. Portable bootstrap: `shared/hosts/CLAUDE.md`. Security boundary: `SECURITY.md`.
