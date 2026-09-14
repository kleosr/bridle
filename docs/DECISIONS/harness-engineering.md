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

## DAIR collection — all 21, one disposition each

[Harness Engineering (21 papers)](https://academy.dair.ai/papers/collections/harness-engineering), read in full (abstracts + DAIR annotations; METR full text). A harness is everything between weights and the world. Dispositions: **solved** = the pack already encodes the mechanism; **adapted** = the mechanism is kept, the runtime is not; **rejected** = would make the pack a second runtime or a self-modifying one.

| # | Paper | Mechanism the harness must provide | Here |
|---|---|---|---|
| 01 | GPT-2 (2019) | Bare loop; the environment scores the output, not the model | **solved** — host loop; proof is command + exit, `prove` independent |
| 02 | GPT-3 few-shot (2020) | Demonstrations in context steer without training | **adapted** — on-match skills and glob companions carry examples; never in always-on (`alwaysOnMaxLines`) |
| 03 | Chain-of-Thought (2022) | Budget tokens, not calls | **rejected** as pack budget — host owns thinking/compaction; the v18 token-budget test was removed on purpose |
| 04 | WebGPT (2021) | Retrieval is an action the model chooses; humans grade *how* it was used | **solved** — `articleNine.context`: map, then targeted retrieval; user approval on irreversible effects |
| 05 | Toolformer (2023) | Declared tools; the action space is what you are willing to execute | **solved** — that filter is the four hooks + `SECURITY.md`; tool descriptions are data, not authority |
| 06 | ReAct (2022) | Interleave thought/action | **rejected** — native now; `packOwnedLoop:false`, no `loop.sh` (tested) |
| 07 | Self-Refine (2023) | Same model grades its own draft | **rejected** as evidence — `stopping.selfGrade:"forbidden"`; refine against an external signal (verify → correct), not an opinion |
| 08 | Reflexion (2023) | Write the environment's reward back as **words** the next trial reads | **adopted** (this pass) — `feature.sh pass` records the signal; `feature.sh note` records the agent's reflection in `lastFailure.nextExperiment`. No judge, no optimizer |
| 09 | InterCode (2023) | Code as action, execution feedback as observation, sandbox is the environment's job | **solved** — command + exit is the observation; sandbox = host; `stop.sh` does not pretend to be the environment |
| 10 | Multi-Agent Collaboration (2023) | Role separation; addressable persistent agents; the paper's own risk list (looping, security, eval) | **adapted** — roles yes (`hunter`/`cut`/`prove`, builder ≠ reviewer), persistence and debate no (invoke-only, independent context) |
| 11 | Voyager (2023) | Skill library: verify a routine, then write it back and retrieve on match; curriculum by priority | **adapted** — skills on match via `skills.txt`; `feature.sh next` is the curriculum; agent-written skills rejected (skills cannot grant permissions) |
| 12 | MemGPT (2023) | CRUD over managed context; transcript ≠ state | **adapted** — the principle (chat is not the SoR) yes; the memory runtime no. Durable memory = git + docs + features + handoff |
| 13 | Recursive LMs (2025) | Long context stays external; the model examines it programmatically; beats compaction | **solved** as principle — progressive disclosure, `AGENTS.md` ≤120 lines, re-probe the workspace instead of trusting the transcript. Recursion runtime = host |
| 14 | DSPy (2023) | Prompt as optimized artifact against a metric | **rejected** — hand-written law by design; the metric idea survives as `evals/tasks.json` coverage, not a scorer |
| 15 | GEPA (2025) | Natural-language reflection on traces beats scalar reward | **rejected** as optimizer; **adopted** as the reason `note` takes prose, not a score |
| 16 | Darwin Gödel Machine (2025) | Agent rewrites its own scaffolding; archive; empirical validation | **rejected** — `hooksFrozen:true`; improvement is human-in-loop via ADR + tests |
| 17 | Meta-Harness (2026) | Outer loop searches harness code with filesystem access to all prior traces/scores | **rejected** as runtime; the substrate it reads (files, exits, history) is what git + `lastFailure` already are |
| 18 | Continual Harness (2026) | Online mutation of prompt/skills/sub-agents within a run, then weight updates | **rejected** — the paper's *first* stage (iterative human-in-the-loop refinement) is exactly where this pack stays by choice |
| 19 | Prime Agent (2026) | Standardize execution, recovery, verification, accounting; leave strategy to the model; keep harness failures from becoming model failures | **solved** — hooks (execution), `feature.sh` (recovery/verification), `failures` map + debugging skill (diagnose the layer first). REPL / recursive subagents = host |
| 20 | OpenJarvis (2026) | Typed spec of independently editable, measurable primitives; accept only non-regressing edits | **solved** — `harness.json` is the spec; `plugins`/`extend` are the editable seams; `tests/run.sh` + regression naming is the non-regression gate |
| 21 | METR time horizon (2025) | Measure task length at 50 % *and* 80 %; the 80 % horizon is 4–6× shorter — reliability is the gap | **adapted** — "flaky is broken", `execution_reliability` and `recovery` dimensions; live horizon scoring is out of band |

Contradictions inside the collection and the side this pack takes: internal self-evaluation (07) vs external signal (08, 09) → external. Imposed loop (06) vs model-owned strategy (13, 19) → model-owned, host-run. Pack-managed memory (12) vs external context read programmatically (13) → external + host compaction. Static harness (§2) vs self-improving harness (§3, 16–18) → static, frozen at four hooks; the improvement loop is a human reading an ADR.

Also considered, not changed: `harness.json` carries both `articleNine` and `subsystems`. They overlap, but they index the same object for two audiences and cost ~30 lines; deleting one to satisfy a duplication count is exactly what `cut` forbids.

## Adopt

- Limits that matter live in hooks, not extra instructions.
- Progressive disclosure: map, then the files this task needs.
- Feature lists are primitives: behavior + verification + state. `passing` is pass-state gated (`scripts/feature.sh`). Each feature's `verification` is the fixture that contains its assertions (`TESTS=<fixture> bash tests/run.sh`), not the whole gauntlet — evidence names what it proves.
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
