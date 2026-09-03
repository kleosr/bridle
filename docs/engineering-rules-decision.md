# Engineering Rules — Selected Architecture

**Date:** 2026-09-03  
**Scope:** kleosr/kleosrules (Cursor harness pack v18.0.0)  
**Status:** Adopted by this audit PR

## Summary

One coherent system: **Cursor-only runtime enforcement** via four global Bash hooks; **law** in User Rules paste + `~/.cursor/rules/*.mdc` (alwaysApply/glob); **on-demand skills**; **local session state** in `NOW.md`; **handbook** in root `AGENTS.md`. No duplicate canonical policy. No vendor files without verified consumers.

## CLAUDE.md decision

| Question | Evidence | Decision |
|----------|----------|----------|
| Is Claude Code a consumer in this repo? | `rg -i 'CLAUDE\|Claude Code\|claude\.md\|\.cursorrules'` → **0 matches**. No install path, hook, CI step, or script reads `CLAUDE.md`. Anthropic docs describe `CLAUDE.md` for Claude Code sessions only ([code.claude.com](https://docs.anthropic.com/en/docs/claude-code/overview)). | **Do not add or retain `CLAUDE.md`.** |
| Bridge pattern if Claude were added later? | Community pattern: symlink or `@AGENTS.md` in tool-specific config (hypothesis only; not adopted). | Document in audit; no file created. |

## Layer model (before → after)

| Layer | Before (untrusted claim) | After (verified) |
|-------|--------------------------|------------------|
| Handbook | Root `AGENTS.md` + 4 nested adapters | **Canonical:** root `AGENTS.md`. **Bridges:** `shared/{hooks,rules,skills,config}/AGENTS.md` point to root; consumed when agents open those trees, not by hooks. |
| User law | Paste + 10 global `.mdc` | Unchanged. Paste = User Rules (manual). Global `.mdc` installed by `fleet_sync.sh install`. |
| Project law | `types.mdc` only in pack `.cursor/rules` | Unchanged. Glob-scoped; not copied to `~/.cursor/rules`. |
| Enforcement | 4 hooks global `~/.cursor` | Unchanged. Cloud Lane-A: 3 hooks via `hooks.cloud.json` (no `sessionStart`). |
| Skills | 10 symlinks under `~/.cursor/skills` | On-demand; listed in `shared/config/skills.txt`. |
| Specialists | hunter/cut/prove → `~/.cursor/agents` | Invoked by name; not always-on. |
| Memory | `NOW.md` + `state/` | Injected by `session_start.sh`; not duplicated in hooks. |
| Retired | HANDOFF, lean hooks, mario team | Confirmed absent; `retired.txt` prunes on install. |

## Precedence (Cursor)

1. **User chat prompt** (highest for a turn)  
2. **User Rules paste** (charter floor per `USER-RULES.paste.txt`)  
3. **Always-apply `.mdc`** in `~/.cursor/rules/` (`agent.mdc`, `ponytail.mdc`, …)  
4. **Glob `.mdc`** when path matches (`types.mdc`, `vibe.mdc`, stack rules)  
5. **Skills** when task/glob matches (`Read SKILL.md` or `/name`)  
6. **Root `AGENTS.md`** — handbook for agents working *in this pack repo*; Cursor cloud may inject via `cloud_instructions`; not installed to `~/.cursor`  
7. **Hook outputs** — `additional_context` (sessionStart), `continue` (beforeSubmitPrompt), `permission` (shell/read)

Hooks do **not** inject `.mdc` or rewrite prompts (`updated_input` banned).

## Install topology

```
FORCE=1 bash scripts/install.sh
  → fleet_sync.sh install
    → ~/.cursor/hooks.json + hooks/*
    → ~/.cursor/rules/{GLOBAL}.mdc
    → ~/.cursor/skills/* (symlinks)
    → ~/.cursor/agents/{hunter,cut,prove}.md
    → pack/.cursor/rules/types.mdc (symlink only)
```

**Uninstall:** `bash scripts/uninstall.sh` removes kleosrules fingerprint only (`before_submit_prompt.sh` in hooks.json). User Rules paste remains manual.

**Update:** Re-run install; idempotent (tests: double install).

**Migration:** Orphan `.cursor/hooks.json` without scripts → `heal_orphan_project_hooks`. Retired rules/skills pruned from destinations via `retired.txt` / `retired-skills.txt`.

## What we deliberately do not do

- No `CLAUDE.md`, `.cursorrules`, or `GLOBAL-RULES.md`
- No Rust gate, pack Python, MCP as core
- No registered `preToolUse` / `stop` / lean LOC hooks
- No per-repo hooks in the pack itself (global-only for local dev)
- No mutating real `~/.cursor` in CI/doctor (fixture HOME instead)

## Proof commands

| Check | Command | Expected |
|-------|---------|----------|
| Doctor (no live install required) | `bash scripts/doctor.sh` | exit 0 |
| Full tests | `bash tests/run.sh` | PASS, exit 0 |
| Isolated lifecycle | `tests/install_lifecycle.sh` (via run.sh) | double install + uninstall + doctor fixture |
| Hook edges | `tests/hook_edges.sh` (via run.sh) | malformed JSON, spaces, missing policy |

See `docs/engineering-rules-audit.md` for full inventory and traceability.
