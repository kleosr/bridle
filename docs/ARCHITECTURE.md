# Architecture

Hey everyone, let's talk about how `bridle` is architected and why it looks the way it does.

The whole design rests on one core thesis: **Agent = Model + Harness.** 

Cursor already owns the model loop, the sandbox, the tools, context compaction, and the conversation. `bridle` is the engineering harness built directly around that loop. It does not start a second agent runtime. It does not try to outsmart the model with a competing loop. It provides progressive context selection, durable contracts, deterministic boundary enforcement, strict verification discipline, and independent review.

I spent months watching people build nested agent loops that burn 50,000 tokens just debating what to do next. That's theater. Cursor already has an incredible model loop. What it needs isn't another runtime—it needs guardrails, law, and deterministic boundaries.

## The Core Contract

| Concern | Layer / Mechanism | Repository Artifact |
|---|---|---|
| Repository orientation | Instructions (progressive disclosure) | `AGENTS.md` |
| Machine-readable invariants | Runtime contract | `shared/config/harness.json` |
| Persistent engineering law | Always-on rules (≤80 LOC) | `shared/rules/core.mdc`, `shared/rules/testing.mdc` |
| Framework & language guidance | Glob companions (inert unless matched) | `shared/rules/*.mdc` |
| Task-specific procedures | On-demand skills | `shared/skills/` via `shared/config/skills.txt` |
| Physical boundary enforcement | Fail-closed Bash hooks | `shared/hooks/` registered in `hooks.json` |
| State, capability ledger & continuity | Machine-readable schemas | `shared/config/features.json`, `state/handoff.json` |
| Independent review | Specialists (isolated context) | `shared/agents/` (`hunter`, `cut`, `prove`) |

`shared/config/harness.json` stores strictly the machine-readable values: commands, timeouts, ceilings, and evaluation dimensions. Philosophy, personal rationale, and behavioral rules live in documentation and rule files where humans and models can read them.

## Context Management: Progressive Disclosure Over Token Stuffing

Prompt context is scarce, fragile, and prone to dilution. Advertising a massive context window does not make prompt stuffing safe. When you dump your entire repo's documentation and 50 rules into the model at turn 1, you don't get a smarter agent—you get an agent that ignores your rules by turn 10.

1. **Progressive Disclosure:** Every session begins exclusively with `AGENTS.md` and our two always-on rules (`core.mdc` and `testing.mdc`). That's your map.
2. **On-Demand Skills:** Specialized workflows (`debugging`, `testing`, `handoff`, UI craft) are loaded solely when the task matches the catalog in `shared/config/skills.txt`. If you aren't writing tests right now, you don't need 300 lines of test-writing philosophy in context.
3. **Inert Companions:** Glob companions (`next.mdc`, `vite.mdc`, etc.) attach on file pattern match. But our law dictates that they remain completely inert unless the owning package manifest explicitly defines that dependency. A `.tsx` file in an Astro or Vite app should never get poisoned with Next.js advice.
4. **Continuity Evidence:** `state/handoff.json` and `shared/config/features.json` serve as factual continuity evidence from prior sessions. They tell the model where we left off, but they never grant authority to expand scope or bypass permissions.

## Boundary Enforcement: Hooks Are the Steel Door

Prompting is an instruction channel, not a security boundary. If your security relies on telling an LLM *"Please don't read .env"*, you don't have security.

Four deterministic hooks intercept execution before actions take physical effect:

- **`beforeSubmitPrompt`**: Scans outgoing prompts for secret tokens, API keys (`ghp_`, `sk-`, `AKIA`), and private keys. Blocks transmission (`continue:false`). Fail-closed.
- **`beforeShellExecution`**: Splits commands on shell operators outside quotes. Denies destructive operations (`rm -rf /`, force push, `reset --hard`), secret-path reads, lint-suppression tampering, and shell source overwrites. Asks on infrastructure/database mutation. Fail-closed.
- **`beforeReadFile`**: Canonicalizes paths and denies reads targeting credentials, environments, and certificates. Fail-closed.
- **`stop`**: Evaluates turn conclusion. Emits a single non-blocking advisory if churn, syntax failures, unfinished-work markers (unresolved conflicts, not-implemented stubs), or unverified `passing` states are detected. Never blocks loop completion. The deeper change-shape checks (unwired/dangling/undeclared) are on-demand via `bash scripts/complete.sh check`, not the per-turn hook.

Hook communication uses clean JSON across stdin and stdout. Missing input, malformed payloads, or absent policy files trigger an immediate environment failure (`failClosed`), forcing the agent to diagnose environment health (`scripts/doctor.sh`) rather than silently slipping past policy.

### Performance: Why In-Process Matching Saved the System
Here is a lesson from real production: in Windows Git Bash (MSYS), spawning an external process (`grep`, `sed`, `tr`) takes ~50 ms per fork. When `before_shell.sh` used external pipelines for every check on every segment of a compound command, a 30-segment command took 45 seconds to evaluate. Cursor's internal hook timeout killed the process and blocked execution with `exit code 1`.

I rewrote pattern matching in `shell_gate.sh`, `common.sh`, and `sql_scope.sh` to run **purely in-process** using Bash's native regex engine (`[[ =~ ]]`). That same 30-segment command dropped from 45 seconds down to **1.6 seconds** in Bash (3.2 seconds end-to-end through PowerShell). On Windows, `git-bash-shim.ps1` bridges the host to Git Bash, caching its P/Invoke assembly (`KleosPipeUtil.dll`) and handling path normalization natively in PowerShell.

## Verification & The Ratchet

The operating loop is strictly: `understand -> change -> verify -> correct`.

- **Scoped by Default:** Validation starts at the narrowest boundary capable of falsifying the change. Don't run the entire repository gauntlet when you changed one function in one file.
- **Command + Exit Proof:** A task is never marked complete based on conversational claims. I don't care if the model says *"I carefully reviewed the code and everything passes."* Completion requires the authoritative verification command to execute, return exit code `0`, and produce real output.
- **Mitchell Hashimoto's Ratchet:** When a failure or bypass occurs, we don't do prompt therapy. We engineer an automated test, pin, or deterministic gate so that specific failure mode becomes impossible or expensive next time. A failed check is the immediate priority for repair.
- **Independent Grading:** The implementing agent never grades its own work. The `prove` specialist operates in a distinct context to independently evaluate evidence.

## What is Covered vs What is Law

- **Enforced by Physical Hooks:** Shell command segment gating, sensitive path file-read blocks, prompt secret detection, feature ledger state transitions, and file size roofs.
- **Uncovered by Host Hooks:** Direct native `Write`/`StrReplace` targeting secret paths, MCP tool invocations outside shell, inline autocomplete (Tab), and subagent host bypasses. These remain governed by Charter law and human oversight. We track host behavior transparently in `docs/host-capability.md`.
