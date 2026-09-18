# Architecture Decision Record: The Engineering Operating System

**Status:** Accepted & Enforced  
**Context:** Foundational architecture, governance layers, and runtime invariants  

## The Core Thesis: Stop Doing Prompt Therapy

Prompt therapy is dead. 

Telling an LLM in a prompt: *"Please be careful with destructive commands, please make sure all tests pass, and please don't leak API tokens"* is not engineering. It's a wish. The moment the model hits a complex multi-file refactor or an unexpected error, those prompt-level promises dissolve.

**Agent = Model + Harness.**

The model is raw cognitive intelligence. The harness is the law. 

Cursor owns the loop, the sandbox, the tools, and context compaction. `bridle` is the engineering layer built around that loop. Prompting is simply one tool inside the harness—it is never the control plane. An agent that actually works in production requires deterministic, physical boundaries that cannot be bypassed by clever conversational persuasion.

## The Principles That Govern This Pack

1. **Guides vs. Sensors (Fowler & Böckeler):** 
   There is a critical distinction between a *guide* (instructions that tell the model what good code looks like) and a *sensor* (deterministic code that physically blocks bad actions). Rules are guides; hooks are sensors. Never use a rule where a hook is required, and never bloat a hook with things that belong in a rule.
2. **Mitchell Hashimoto's Ratchet:** 
   When an agent makes a mistake, evades a check, or breaks a convention, we don't rewrite the prompt with more polite adjectives. We engineer a pin. We write an automated test, an in-process regex check, or a hook assertion so that specific failure mode becomes expensive or physically impossible next time.
3. **Progressive Disclosure:** 
   The model's usable context window is much smaller than the advertised token limit. If you dump your whole codebase, 30 rules, and every skill into the prompt on turn 1, you destroy the model's reasoning capacity. Start with `AGENTS.md`. Load companions only when files match. Load skills only when tasks demand them.
4. **Verifiable Proof Over Model Claims:** 
   A model telling you *"Everything looks great and all 50 tests are passing"* is not evidence. In `bridle`, "Done" has exactly one meaning: the authoritative verification command ran in the terminal, returned exit code `0`, and produced verifiable artifacts. If the validator didn't run, the task is not done. Period.
5. **Frozen Boundary Surface:** 
   We freeze the hook count at four. We don't add random lifecycle hooks every time someone has an idea. New capabilities extend through rules or skills, not through hook sprawl.

## The Runtime Contract

| Responsibility | Responsible Layer | Implementation |
|---|---|---|
| Model loop, workspace sandbox, tool calling | Host (Cursor) | Native host runtime |
| Identity, authorization limits, proof standards | Charter | `USER-RULES.paste.txt` → `kleosr.mdc` |
| Code craft, size limits, complexity ceilings | Always-on rules | `core.mdc` (≤80 LOC) |
| Verification discipline & regression naming | Always-on rules | `testing.mdc` (≤80 LOC) |
| Framework-specific idioms & patterns | Glob companions | `next.mdc`, `vite.mdc`, `postgres.mdc`, etc. |
| Specialized task procedures | On-demand skills | `shared/skills/` (invoked on match) |
| Session coordinator | Custom-mode skill (explicit invoke) | `shared/skills/kleosr/SKILL.md` (`mode: true`, `disable-model-invocation: true`) |
| Deterministic boundary interception | Fail-closed hooks | Four event scripts in `shared/hooks/` |
| Capability ledger & progress verification | Machine contract | `shared/config/features.json` via `scripts/feature.sh` |
| Cross-session continuity | Schema-validated state | `state/handoff.json` via `scripts/handoff.sh` |
| Independent verification & review | Specialist subagents | `hunter`, `cut`, `prove` in `shared/agents/` |

## Rejection of Agent Theater

I built `bridle` by ruthlessly cutting out things that sound impressive in demo videos but fail in real production:

- **No Pack-Owned ReAct Loops:** Cursor already has a tuned, highly optimized model loop. Trying to run an agent loop *inside* another agent loop just burns tokens, adds massive latency, and causes compounding errors.
- **No Multi-Agent Debate Societies:** Having three peer models talk to each other about code quality in a chat thread is theater. Real software quality comes from deterministic compilers, linters, and unit test suites.
- **No Vector Memory Bloat:** Unstructured vector memory retrieves stale, contradictory advice from chats you had three weeks ago. Real continuity belongs in git, clean feature ledgers (`features.json`), and validated handoff schemas (`handoff.json`).
- **No Prompt Stuffing on Session Start:** Forcing 15 rules into every single turn degrades model attention. Keep always-on rules under 80 lines and use progressive disclosure.

## Where This Comes From

This system stands on the shoulders of real engineering disciplines:
- **Mitchell Hashimoto:** The engineering ratchet—every failure becomes a test pin.
- **Martin Fowler & Birgitta Böckeler:** The separation between instructional guides and deterministic sensors.
- **Addy Osmani:** Loop engineering and treating prompt instructions as falsifiable assertions.
- **Deterministic Security:** Fail-closed defaults, strict least privilege, and treating model-generated commands as untrusted input.
