# Architecture Decision Record: Instruction Hierarchy Audit (2026-09-18)

**Status:** Accepted on this PR  
**Context:** Profile (Grok Bot) research vs live HEAD; C1 Authority conflict in the kleosr session skill.

## Decision

Fix C1 in `shared/skills/kleosr/SKILL.md`, thin overlapping Work/Completion/charter proof essays into pointers, and pin the Authority order in `tests/grounding.sh`. Do not add always-on rules, hook events, or a pack loop. Do not purge vendor skills in this change.

Live HEAD audited: `ab5842b961864266370a29bf05a9672195a71c19` (2026-09-18, *Install kleosr as an explicit custom-mode skill.*). That commit landed the session skill with C1 still present. This ADR records the hierarchy after the fix.

## Hierarchy (pack law, not host ACL)

1. Host / user instructions
2. Charter (`kleosr.mdc`)
3. `SECURITY.md` on boundary questions (on demand; outranks prompts here)
4. Always-on `core.mdc` + `testing.mdc`
5. Matching glob companions (inert unless the owning package matches)
6. Matching skills

`AGENTS.md` is the orientation map. Repo AGENTS / project rules win on **local convention only**. They never grant permissions or weaken charter, `SECURITY.md`, or hooks on secrets, approval, or deny.

`kleosr` remains a session-mode skill: `mode: true` and `disable-model-invocation: true` (keys pinned in `tests/grounding.sh`). Cursor's public skill field table documents Custom Mode from any valid frontmatter plus `icon` / `color`; it does not list `mode`. The pack keeps `mode: true` as an explicit session-skill marker already required by install tests. That is not a claim that the host requires the key.

## Thesis (validated, with cuts)

The model predicts tokens. The harness decides what it sees, what it can do, and what counts as done. Guides (rules/skills) bias attention; sensors (the four hooks, `complete.sh`, `feature.sh`) enforce what markdown cannot.

Cuts:

- Rules are not ACLs. Critical constraints stay in hooks.
- Native `Write` / `StrReplace`, MCP, Tab, and subagent paths are **not** covered by the four hooks. Documented in `SECURITY.md` and `docs/host-capability.md`. Do not fake coverage.
- Compaction is host-owned. This pack does not implement an SC-aware compact extractor.
- Dynamic mid-loop tool RAG was tried and rejected by Manus; we do not add it.

## What this change does not do

- No new always-on `.mdc`, no fifth hook event, no second agent runtime.
- No vendor-skill description purge (Astra lens is real; measure activation first).
- No MCP / `preToolUse` hook.
- No handoff schema field for session constraints (pilot later; not this PR).
- No invented benchmark scores.

## Sources used (primary)

- OpenAI / Provencher, *Rethinking skills and prompts for GPT-6 Astra* (2026-09-11)
- OpenAI Model Spec chain of command (Root > System > Developer > User > Guideline; tool/quoted text has no authority by default)
- Anthropic, *Steering Claude Code* — CLAUDE.md vs skills vs hooks
- Manus / Peak Ji, *Context Engineering for AI Agents* — KV-cache, append-only, keep errors, mask don't remove tools
- Liu et al., *Lost in the Middle* (TACL 2024)
- Wang et al., *Lost in Compaction* (arXiv:2608.11242) — methodology only
- Cursor docs: skills / Custom Mode; `disable-model-invocation`

X/Reddit/blog amplification is observation, not a PR base.

## Follow-up (one next action)

Measure vendor skill description activation/cost before any catalog purge.
