# Engineering Rules — Selected Architecture

**Date:** 2026-09-03  
**Scope:** kleosr/kleosrules (Cursor harness pack v18.0.0)  
**Status:** Adopted by this audit PR

## Summary

One coherent system: **Cursor-only runtime enforcement** via five global Bash hooks; **law** in User Rules paste + `~/.cursor/rules/*.mdc` (alwaysApply/glob); **on-demand skills**; **local session state** in `NOW.md`; **handbook** in root `AGENTS.md`. No duplicate canonical policy. No vendor files without verified consumers.

## CLAUDE.md decision

| Question | Evidence | Decision |
|----------|----------|----------|
| Is Claude Code a consumer in this repo? | `rg -i 'CLAUDE\|Claude Code\|claude\.md\|\.cursorrules'` → **0 matches**. No install path, hook, CI step, or script reads `CLAUDE.md`. Anthropic docs describe `CLAUDE.md` for Claude Code sessions only ([code.claude.com](https://docs.anthropic.com/en/docs/claude-code/overview)). | **Do not add or retain `CLAUDE.md`.** |
| Bridge pattern if Claude were added later? | Community pattern: symlink or `@AGENTS.md` in tool-specific config (hypothesis only; not adopted). | Document in audit; no file created. |

## Layer model (before → after)

| Layer | Before (untrusted claim) | After (verified) |
|-------|--------------------------|------------------|
| Handbook | Root `AGENTS.md` + 4 nested adapters | **Canonical:** root `AGENTS.md`. **Bridges:** `shared/{hooks,rules,skills,config}/AGENTS.md` point to root; consumed when agents open those trees, not by hooks. |
| User law | Paste + 11 global `.mdc` | Unchanged topology. Paste = User Rules (manual). Global `.mdc` installed by `fleet_sync.sh install`. |
| Project law | none (`SHARED=()`) | `types.mdc` moved GLOBAL alwaysApply 2026-09-04. |
| Enforcement | 5 hooks global `~/.cursor` | Local: sessionStart, beforeSubmitPrompt, beforeShellExecution, beforeReadFile, stop. Cloud Lane-A: 3 hooks via `hooks.cloud.json` (no `sessionStart`, no `stop`). |
| Skills | 10 symlinks under `~/.cursor/skills` | On-demand; listed in `shared/config/skills.txt`. |
| Specialists | hunter/cut/prove → `~/.cursor/agents` | Invoked by name; not always-on. |
| Memory | `NOW.md` + `state/` | Injected by `session_start.sh`; not duplicated in hooks. |
| Retired | HANDOFF, lean hooks, mario team | Confirmed absent; `retired.txt` prunes on install. |

## Precedence (Cursor)

1. **User chat prompt** (highest for a turn)  
2. **User Rules paste** (charter floor per `USER-RULES.paste.txt`)  
3. **Always-apply `.mdc`** in `~/.cursor/rules/` (`agent.mdc`, `ponytail.mdc`, `pnpm.mdc`, `complexity.mdc`, `vibe.mdc`, `testing.mdc`, `types.mdc`)  
4. **Glob `.mdc`** when path matches (`next.mdc`, `vite.mdc`, `astro.mdc`, `postgres.mdc`)  
5. **Skills** when task/glob matches (`Read SKILL.md` or `/name`)  
6. **Root `AGENTS.md`** — handbook for agents working *in this pack repo*; Cursor cloud may inject via `cloud_instructions`; not installed to `~/.cursor`  
7. **Hook outputs** — `additional_context` (sessionStart), `continue` (beforeSubmitPrompt), `permission` (shell/read)

Hooks do **not** inject `.mdc` or rewrite prompts (`updated_input` banned).

## Install topology

```
FORCE=1 bash scripts/install.sh
  → fleet_sync.sh install
    → ~/.cursor/hooks.json + hooks/*
    → ~/.cursor/rules/{GLOBAL}.mdc (includes types)
    → ~/.cursor/skills/* (symlinks)
    → ~/.cursor/agents/{hunter,cut,prove}.md
    → pack `.cursor/rules` pruned of GLOBAL names (SHARED empty)
```

**Uninstall:** `bash scripts/uninstall.sh` removes kleosrules fingerprint only (`before_submit_prompt.sh` in hooks.json). User Rules paste remains manual.

**Update:** Re-run install; idempotent (tests: double install).

**Migration:** Orphan `.cursor/hooks.json` without scripts → `heal_orphan_project_hooks`. Retired rules/skills pruned from destinations via `retired.txt` / `retired-skills.txt`.

## What we deliberately do not do

- No `CLAUDE.md`, `.cursorrules`, or `GLOBAL-RULES.md`
- No Rust gate, pack Python, MCP as core
- No registered `preToolUse` / lean LOC-size hooks. `stop` is registered locally for churn only (not file size). Cloud `hooks.cloud.json` still omits `stop`.
- No per-repo hooks in the pack itself (global-only for local dev)
- No mutating real `~/.cursor` in CI/doctor (fixture HOME instead)

## Quality system: checks, not adjectives

"Highest quality" is only meaningful as a set of falsifiable gates. Each row is a gate that exists today or a bounded extension; nothing here is a slogan.

| Stage | Gate | Observable | Status |
|-------|------|------------|--------|
| Before write | Grounding: Grep/Read the files you will change; one-sentence declaration (outcome, files, proof) | Chat contains the declaration before the first Write | law (`agent.mdc`, paste); unenforced by hook |
| Write | Ladder: no code → reuse → stdlib → platform → dep → one-liner → minimum | Diff size; no new dependency without a ladder step cited | `ponytail.mdc` + skill |
| Write | Cyclomatic ≤ repo cap (else 10); never disable lint | `before_shell.sh` denies `complexity:off`, `noqa: C901`, clippy allow | **hook-enforced** |
| Write | No Shell source-write; use Write/StrReplace | `before_shell.sh` denies `> x.ts`, `sed -i`, `tee`, heredoc | **hook-enforced** |
| Write | Types: no `any` / un-narrowed `unknown` / blind cast / unwrap | `types.mdc` alwaysApply | law |
| Read | No secrets into model context | `before_read_file.sh` failClosed | **hook-enforced** |
| Prompt | No tokens in prompts | `before_submit_prompt.sh` `continue:false` | **hook-enforced** |
| Test | Red → green; cite the command and exit code | `bash tests/run.sh` PASS count in chat and NOW.md | harness |
| Review | hunter (security), cut (dead code), prove (independent re-run) | subagent reports, empty is a pass | on demand |
| Memory | NOW.md Proof reflects the last real run | `session_start.sh` injects it; stale Proof is a defect (fixed this PR) | harness |

Extensions considered and **not** adopted without an operator decision:

- Registering `afterFileEdit` to lint touched files (rejected; the 2026-09-03 runtime audit instead added `stop` as the 5th event — see `docs/engineering-system.md`).
- Registering `preToolUse` to require a declaration before Write (would need conversation parsing; ARCHITECTURE.md explicitly bans conversation police).
- Auto-injecting `ponytail.mdc` at sessionStart (ARCHITECTURE.md: law and state must not share one dump).

The system's efficiency comes from what it refuses to load: 5 hooks, ~40 injected lines, 7 alwaysApply rules (testing and types joined 2026-09-04; complexity and vibe joined 2026-09-03), everything else on path or on demand.

## 2026-09-04 — Quality roofs

Operator asked for ten metrics as always-on law. Full audit: `docs/quality-roofs-audit.md`.

Adopted: extend `complexity.mdc`, `ponytail.mdc`, `testing.mdc`, `types.mdc`, and the Retrieval harness paragraph in `USER-RULES.paste.txt`. Flip `testing.mdc` and `types.mdc` to `alwaysApply: true`. Move `types.mdc` from SHARED/project to GLOBAL.

Rejected: ten new `.mdc` files; raising cyclomatic 10→22; raising file roof 300→500; a total ban on `unknown`; adding coverage/mutation/Sonar/Halstead tools to this Bash pack; hook-enforcing LOC or coverage.

Working numbers: cyclo repo-or-10 never 22; cognitive 22 / Halstead 80 / CRAP 25 when already measured; LOC hard 300 never 500; this-turn coverage 100% when a job exists; 0 surviving mutants when a mutator exists; zero dead/redundant; no `any`; no un-narrowed `unknown`.

## 2026-09-05 — Nested AGENTS.md deleted

Sept 3 kept four `shared/*/AGENTS.md` bridges. `agents.md` nearest-file precedence means a nested file shadows root, and Cursor re-attaches it on every Read in that tree (observed this session and in `docs/runtime-grounding-audit.md`). The adapters restated the root map. Deleted. Root `AGENTS.md` is the only handbook. Do not re-add.

## 2026-09-05 — Astra article (pvncher)

[Rethinking skills and prompts for GPT-6 Astra](https://x.com/i/article/2095989703967125509): skill descriptions must not say “when this alwaysApply `.mdc` applies” (pick-me). Grounding is the files you will change, not a repo map. Proof is the command this change can break; local fixtures run without asking. Hook steel and irreversible-approval stay.

## Proof commands

| Check | Command | Expected |
|-------|---------|----------|
| Doctor (no live install required) | `bash scripts/doctor.sh` | exit 0 |
| Full tests | `bash tests/run.sh` | PASS, exit 0 |
| Isolated lifecycle | `tests/install_lifecycle.sh` (via run.sh) | double install + uninstall + doctor fixture |
| Hook edges | `tests/hook_edges.sh` (via run.sh) | malformed JSON, spaces, missing policy |

See `docs/engineering-rules-audit.md` for full inventory and traceability.
