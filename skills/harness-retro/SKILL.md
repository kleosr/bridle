---
name: harness-retro
description: >-
  Turn a repeated agent failure into a harness fix (rule, skill, TOOLCHAIN,
  or hook) instead of only patching product code. Use when the same mistake
  recurs, the user says harness retro, or keep-rate drops for a pattern.
---

# Harness retro

Hashimoto + Process-Not-Patches: every repeated mistake → fix the process
that produced it, not only the product file. See `docs/ARCHITECTURE.md`.

## Workflow

1. State the **symptom** (what the agent did wrong) with evidence.
2. Classify by **five-layer unit** (first match wins):

| Layer | Unit broke | Typical fix surface |
|-------|------------|---------------------|
| Prompt | One input / format / role wrong | User Rules roof line; companion; skill prompt |
| Context | Forgot decision / window junk | wiki hot/index/write-back; HANDOFF; curation |
| Harness | No tools / no verify / gate thrash | TOOLCHAIN; Bash hooks + policy; fleet_sync |
| Loop | Stopped mid-task; “done” without goal | ship-loop; Session goal; stop followup |
| Graph | Clash / orphan notes / no shared state | 0xJeyx steps: nodes/edges/state/reviewer/isolate/orchestration |

Legacy surfaces still map: `agent.mdc` → Prompt/Harness soft; Skill → any;
TOOLCHAIN/hook → Harness; `AGENTS.md` → Context/map.

3. Propose the **smallest** harness change (one layer). Prefer Skill over
   always-on prose; prefer TOOLCHAIN over soft reminders; prefer hook only
   for hard SAFETY / MUST-NEVER/M.
4. Graph-layer failures: map to 0xJeyx — missing specialty node, missing edge,
   unclear shared state, weak reviewer, unisolated failure, or hand-rolled
   orchestration theater. Prefer Cursor + Bash hooks + skills + vault.
5. If authorized: apply in **this rules pack**, then
   `FORCE=1 bash hooks/fleet_sync.sh all` (or `install` / `verify`).
   Never reintroduce Rust kleos-gate or pack Python.
6. Optionally note keep-rate: did humans revert similar agent commits recently?

## Anti-patterns

- Thickening User Rules with craft essays
- Adding a 5th always-on Graph Engineering `.mdc`
- Hand-patching agent output instead of rulebook/judge
- Reintroducing Spec Kit, LangGraph/CrewAI pack theater, or sticky epic state
- Fixing only the product bug when the agent will repeat the process error

## Report

Symptom → five-layer unit → harness change → install/verify evidence → residual.
