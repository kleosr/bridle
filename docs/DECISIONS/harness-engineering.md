# Harness engineering ingest (ADR)

Status: Accepted. Not law. Not injected. Not installed.

Sources: [Learn Harness Engineering](https://walkinglabs.github.io/learn-harness-engineering/es/) (complete course: L01–L14, P01–P08, resource library, `harness-creator`, frontier breakdowns of Pi / Claude Code / Codex / DeepSeek Harness); santi, *Harness Engineering: explicado desde cero*; [LangChain *Anatomy of an agent harness*](https://www.langchain.com/blog/the-anatomy-of-an-agent-harness); [OpenAI harness engineering](https://openai.com/index/harness-engineering/); [DAIR.AI Harness Engineering collection](https://academy.dair.ai/papers/collections/harness-engineering) (21 papers).

The formula is `agente = modelo + harness`. Cursor is already the loop (tools, history, compaction). This pack is the **user harness** around that host. Do not clone the course's Electron app, Node scaffolder, `init.sh` template, or a second ReAct runtime.

## Two maps, one pack

The Spanish article's nine pieces (tools, loop, memory, context, environment, goal+verify, permissions, observability, evals) and the course's five subsystems (instructions, state, verification, scope, lifecycle) describe the same object. Here they are indexes, not always-on prose. Machine map: `shared/config/harness.json` (`articleNine`, `subsystems`, `invariants`).

| Course / article | Here |
|---|---|
| Instructions | `AGENTS.md` directory page + charter + `.mdc`. Map: `harness.json`. |
| Tools | Cursor tools. Hook JSON I/O (`shared/schema/hook-io.schema.json`). Skills cannot grant permissions. |
| Environment | Host sandbox + `scripts/ready.sh` (L06 bootstrap contract) + doctor inventory. No pack VM. |
| State | `shared/config/features.json` + optional `state/handoff.json`. Git + `docs/` for durable decisions. |
| Feedback / verification | Command + exit. Failed pass records `lastFailure`. `prove` independent. `stop.sh` advisory. |
| Scope | One `in_progress` feature. Ponytail + stop churn. |
| Lifecycle | `ready.sh` → one feature → verify → record → handoff. No `sessionStart` injection. |
| Loop / graph | Host owns the loop. Review graph is data in `harness.json` (`hunter` / `cut` / `prove`). |
| Observability | Hook `reason` codes + command + exit in the reply. No OTel. |
| Evals | `evals/tasks.json` + `scripts/eval.sh check`. Live agent-on-task scoring is out of band. |

## Frontier — adopt the mechanism, not the product

| Product | Worth taking | Leave with the host |
|---|---|---|
| **Pi** | Minimal core; skills/hooks as programmable extensions; on-demand load | Pack-owned compaction / session tree |
| **Claude Code** | Layered memory (charter / `.mdc` / skills / repo docs); Stop hooks; subagent isolation | Five-layer compaction, auto-memory, `PreToolUse` |
| **Codex** | Repo as source of truth; `AGENTS.md` as a directory page; verification in the spec | Worktree VM, spawn_agent runtime |
| **DeepSeek** | Plugins (skills, glob companions, optional/design); capability seams (`lib/host.sh`); model-visible ≈ logged | Pack-owned event bus / plugin kernel |

## DAIR collection — adopt / reject

[Harness Engineering (21 papers)](https://academy.dair.ai/papers/collections/harness-engineering): a harness is everything between weights and the world. ReAct is now native tool use, so a modern harness should **stop imposing a second thought/act loop**. Reflexion belongs as data (`lastFailure`), not a writer-as-judge. Voyager maps to on-match skills. Paper 21 measures **task-length completion**; this pack's evals are structural coverage, not a live SWE-bench.

Reject as pack runtime: DSPy prompt compilers, GEPA, Darwin-Gödel, [Meta-Harness](https://arxiv.org/abs/2603.28052), Self-Harness, [Agentic Harness Engineering auto-evolution](https://arxiv.org/abs/2604.25850). Those rewrite the harness. This pack does not.

## Adopt

- Limits that matter live in hooks, not extra instructions.
- Progressive disclosure: map, then the files this task needs.
- Feature lists are primitives: behavior + verification + state. `passing` is pass-state gated (`scripts/feature.sh`).
- “Listo” is not done. Proof is outside the model.
- Builder ≠ reviewer: `hunter` / `cut` / `prove` independent context.
- Clean handoff: schema-validated `state/handoff.json`, not `NOW.md` / `PROGRESS.md` / `claude-progress.md` as source of truth.
- Init is its own phase: `scripts/ready.sh` (can start, can test, can see progress, can hand off). Output is infrastructure, not code.
- Diagnose recurring failure by layer (task spec, context, environment, verification, state), not by blaming the model.
- Third pass: subtract ceremony. Craft quality is a roof (`core.mdc`) plus mechanical sensors (churn, size, syntax, pass-state). Do not grow always-on `.mdc`. Extend via `skills.txt` and glob companions; hook events stay frozen at four.

## Reject (if copied literally)

A pack-owned agent loop; timer loops; tool-retry or compaction middleware; `NOW.md` / `PROGRESS.md` / `LEARNING.md` as SoR; MCP as core; eval platforms; extra hook events including `preToolUse`; `updated_input`; `sessionStart` prompt injection; OS-specific install trees; encoding the nine sections into always-on `.mdc`; shipping `harness-creator` Node scripts or the course Electron templates; self-modifying / meta-harness runtimes.

## Activation

Charter edits still need a new chat after paste. This ADR does not activate them.
