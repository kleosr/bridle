# Engineering OS (ADR)

Status: Accepted. Not law. Not injected. Not installed.

The host owns the model loop. This pack is the durable engineering layer around it: instructions select context, contracts preserve state, hooks enforce deterministic boundaries, and tests establish evidence.

## Principles

- Optimize for readability, correctness, changeability, and cohesion; line count is not a goal.
- Put each concern in one layer: rules for durable constraints, skills for task expertise, hooks for deterministic checks, state for continuity, and reviewers for independent judgment.
- Load context on match. `AGENTS.md` is a directory page; `shared/config/harness.json` is the runtime contract; topic docs and skills stay off the default path.
- Keep hook events frozen at four. New language, framework, or verification concerns extend through rules, skills, or existing commands rather than a new runtime.
- Make completion evidence-based. Run the narrowest check that can falsify the change; report the command, exit, and unverified remainder.

## Runtime contract

| Concern | Owner |
|---|---|
| Loop, tools, sandbox, conversation | Host |
| Engineering constraints and review standards | `USER-RULES.paste.txt`, `core.mdc`, `testing.mdc` |
| Task procedures | `shared/skills/` on match |
| Deterministic boundary checks | `shared/hooks/` on four supported events |
| Durable state and recovery | Git, `docs/`, `features.json`, optional `handoff.json` |
| Independent review | `hunter`, `cut`, and `prove` |

## Source boundary

The design adopts progressive disclosure, external verification, fail-closed boundary checks, feature pass-state, and isolated reviewers. Sources include OpenAI's harness-engineering guidance, Anthropic's context-engineering guidance, and the Learn Harness Engineering course.

It rejects a pack-owned ReAct loop, session-start prompt injection, extra hook events, self-modifying harnesses, timer loops, vector-memory stacks, multi-agent debate, and always-on policy encyclopedias. The host already provides those mechanisms or they add ceremony without proof.

Machine implementation: `shared/config/harness.json`. Narrative: `docs/ARCHITECTURE.md`. Hook rationale: `docs/DECISIONS/hooks.md`.
