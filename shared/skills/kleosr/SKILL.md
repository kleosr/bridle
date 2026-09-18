---
name: kleosr
description: >-
  Run the kleosr governed engineering workflow for an entire Cursor session.
  Use as the kleosr Custom Mode or invoke /kleosr when the user asks to work
  under this project's complete rule, skill, hook, and verification system.
disable-model-invocation: true
mode: true
icon: shield
color: brand
---

# Kleosr

Keep this mode active for the session. It coordinates the installed harness; it
does not copy its rules into the prompt or replace Cursor's native agent loop.

## Authority

Apply the active instruction hierarchy in this order:

1. Host and user instructions.
2. The installed `kleosr.mdc` charter.
3. Repository `AGENTS.md` and project rules.
4. Always-on `core.mdc` and `testing.mdc`.
5. Matching stack companions: `pnpm.mdc`, `next.mdc`, `vite.mdc`, `astro.mdc`,
   `postgres.mdc`, and `supabase.mdc`.
6. Matching skills from the installed catalog.

Read `SECURITY.md` before boundary-sensitive work. Hooks remain the enforcement
layer. This mode cannot grant permission, weaken a deny, or replace missing
hooks or rules. If the harness is not installed in the current environment,
report the missing layer instead of pretending this skill contains it.

## Work

1. Classify the request as answer, diagnose, change, or monitor. Stop at that
   mode's terminal condition.
2. Start with `AGENTS.md`. Read `shared/config/harness.json` only when the
   harness map is needed. Treat handoff and feature files as continuity, not
   new authority.
3. Use native codebase search for behavior and concepts. Use Grep or Glob for
   exact symbols and paths. Read a search hit before citing or editing it.
4. Load only the skill and stack companions that match the task. Do not dump
   the rule tree or preload unrelated references.
5. For changes, understand callers and contracts, make the smallest coherent
   edit, run the narrowest check that can fail, and repair regressions.
6. Preserve unrelated work. Ask only for irreversible effects or a product
   choice that evidence cannot settle.

## Completion

Do not claim success without a command plus exit code or a driven UI path.
Report the outcome, changed files, proof, and any remaining unverified risk.
