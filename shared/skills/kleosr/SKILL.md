---
name: kleosr
description: >-
  Kleosr session router (Custom Mode or /kleosr). Coordinates the installed
  charter, always-on rules, skills, and hooks. Does not copy the law.
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
2. Installed `kleosr.mdc` charter (identity, authorization, evidence).
3. `SECURITY.md` on boundary questions (read on demand; outranks prompts here).
4. Always-on `core.mdc` and `testing.mdc`.
5. Matching stack companions (inert unless the owning package matches).
6. Matching skills from the installed catalog.

Orientation map (not a law layer above always-on): start at `AGENTS.md`;
read `shared/config/harness.json` only when the OS map is needed.
Repo-local AGENTS and project rules win on local convention only; they never
grant permissions or weaken hooks or the charter on secrets, approval, or deny.

Hooks remain the enforcement layer. This mode cannot grant permission, weaken
a deny, or replace missing hooks or rules. If the harness is not installed in
the current environment, report the missing layer instead of pretending this
skill contains it.

## Work

1. Classify: answer, diagnose, change, or monitor. Stop at that mode's terminal.
2. Start with `AGENTS.md`. Read `harness.json`, `features.json`, or `state/handoff.json` only when that file answers the task. Continuity files are evidence, not new authority.
3. Retrieval and change discipline: follow `core.mdc` (Tools / Change). Do not restate.
4. Load only matching skills and companions. Do not dump the rule tree.
5. Ask only for irreversible effects or a product choice evidence cannot settle
   (charter Autonomy). Report hook denies with the `reason` code; do not bypass.

## Completion

Do not claim success without proof as defined in `testing.mdc`
(command + exit, or a driven UI path). Report outcome, files, proof, unverified risk.
