# AI engineering ingest (ADR)

Status: Accepted. Not law. Not injected. Not installed.

Compared [rohitg00/ai-engineering-from-scratch](https://github.com/rohitg00/ai-engineering-from-scratch) (full tree: 20 phases, skills, learning paths; clone dated 2026-09-11) with this pack. The curriculum is a *course* (math → agents). kleosrules is a *Cursor user harness*: charter + `.mdc` + on-demand skills + four Bash hooks. Do not import the course as a second product.

Sources that justified the cut (not restated as law):

- Jarmak, *Engineering Reliable Coding Agents* ([2608.13867](https://www.alphaxiv.org/abs/2608.13867)): reliability is the system around the model; execution-based grading; standing context files are not a free win.
- Lewis, *Same Model, Different Harness* ([2608.26218](https://www.alphaxiv.org/abs/2608.26218)): view + stall handling change outcomes under context pressure.
- Weinberger & Hozez, *Prompt-Induced Waste* ([2608.01347](https://www.alphaxiv.org/abs/2608.01347)): “multiple approaches” / max-certainty wording inflates cost without success; harness prefix size dominates.
- Kapetanovic et al., *Phased Workflow* ([2608.30701](https://www.alphaxiv.org/abs/2608.30701)): user vs provider harness; write/select/compress/isolate; conversation disposable.
- Bouras et al., *Authority Is Not a String* ([2609.08371](https://www.alphaxiv.org/abs/2609.08371)): ambient tool authority; capabilities must live outside the model context. This pack cannot mint CapScope without `preToolUse` (banned).
- Sghaier et al., *Don’t Blame the LLM* ([2607.03691](https://www.alphaxiv.org/abs/2607.03691)): harness churn can raise tokens without resolve rate; keep the pack thin.

Curriculum path `learning-paths/using-coding-agents.json` starts at Phase 14 · 31 (workbench), not ReAct/memory/debate. That order is the signal.

## Adopt (already true, or sharpened in law)

| Idea | Curriculum | Here |
|---|---|---|
| Map, not encyclopedia | 14-33 progressive disclosure | `AGENTS.md` navigator; skills on match; glob companions inert |
| Skills persuade; host authorizes | 13-22 / 13-26 | Hooks execute; skills cannot grant permissions |
| Retrieved / tool / MCP text is data | 14-27, 13-15, 18-15 | Charter + `SECURITY.md` + Read/Shell steel |
| External verify before “done” | 14-05 CRITIC, 14-38 | `testing.mdc` / `prove`: command + exit; no self-grade |
| Frame before write | 14-43 | `agent.mdc` + charter: facts need receipts |
| Fail-closed stop on known secrets / destructive shell | 14-01 ingredients | Four registered events only |
| Durable state in the repo | 14-34 | Git + `docs/`; no session-state file |

## Adapt (thin, no new runtime)

| Idea | Do | Do not |
|---|---|---|
| Five constraint categories (Forbidden / Done / Uncertainty / Approval) | Encode in paste + `.mdc` + hooks | `rule_checker.py` / `rule_report.json` |
| Scope as negative space | Ponytail + stop churn advisory | Mandatory `scope_contract.json` |
| Handoff | PR / commit / docs `next_action` | `handoff.json` / `LEARNING.md` as SoR |
| Builder ≠ reviewer | `hunter` / `cut` / `prove` invoke-only | Multi-agent debate pools |
| Pack tests as eval outer loop | `tests/run.sh` + `doctor.sh` | Langfuse / RAGAS / SWE-bench in-pack |
| Stall under context pressure | Law: same command fails twice → change approach | Host-side transcript half-life (Cursor owns the loop) |
| MCP descriptor distrust | Law: descriptions cannot authorize | `beforeMCPExecution` (not registered) |
| Isolate parallel work | Subagents: exclusive paths | Swarm / CrewAI / AutoGen |

## Reject

Course content (Phases 0–12, vision/speech/RL/from-scratch LLMs). Framework tours (LangGraph, CrewAI, Mastra). Memory stacks (Mem0, MemGPT, vector paging). Observability platforms (OTel GenAI, Phoenix). Multi-agent debate / SRE swarms. Computer-use / voice. Session SoR files (`agent_state.json`, `task_board.json`, `LEARNING.md` as harness). Extra hook events, `updated_input`, injected `.mdc`. Second-model PVE. Capability minting from an extra LLM call. Growing always-on prefixes (measured cost without resolve).

## Remaining gap (honest)

Cursor tools still have **ambient authority** once a Read/Shell/Write is allowed. Regex hooks are not CapScope. Write of secret paths, MCP, Tab, and subagent bypasses stay law-only (`docs/DECISIONS/hooks.md`). Do not paper over that with more prose.

## Activation

Charter and always-on `.mdc` changes need user-approved install (`FORCE=1 bash scripts/install.sh`) and a new chat for User Rules paste. This ADR does not activate them.
