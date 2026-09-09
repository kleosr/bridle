# AGENTS.md — Repository Agent Handbook

Navigator for agents in this pack. Do not paste this file into Task briefs.

Law lives elsewhere. This file is a map.

## Law

- **Charter (User Rules paste, cloud floor):** `shared/rules/USER-RULES.paste.txt`
- **Roofs (caps and quality floors):** `shared/rules/complexity.mdc`, `ponytail.mdc`, `testing.mdc`, `types.mdc`
- **Map of those numbers:** `docs/quality-roofs-audit.md`
- **Steel (do not slim):** four registered hooks — `before_submit_prompt.sh`, `before_shell.sh`, `before_read_file.sh`, `stop.sh`
- **Secrets:** `SECURITY.md`. Never put secret values in paste, hooks, chat, or notes.

## Pack

- Optional handoff note for unfinished work. Muscle = the four hooks. Local-host install (`FORCE=1 bash scripts/install.sh` → `~/.cursor`); project opt-in. Never Lane-A into this pack.
- No Rust kleos-gate. No pack Python. MCP is optional, never core.
- Output: never `updated_input` (no `preToolUse`). `beforeSubmitPrompt` → `continue`. `stop` → one `followup_message`.

## Skills (on demand)

Stored in `shared/skills/` (not `.agents/skills`). Read `SKILL.md` only when the task matches. Description lines are routers; detail files load after.

- Core: `ponytail`, `debugging`, `testing`, `complexity`
- Design: `design-stack` → one of `premium-ui-craft`, `landing-page-design`, `redesign-existing-projects`
- Specialists: `writing-pr`. Review: `/hunter` `/cut` `/prove` (`~/.cursor/agents`; @-attach if the slash menu misses them).

## Workflows

- **Verify (hooks/scripts/tests/rules):** `chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh` → `bash -n` those scripts → `bash scripts/doctor.sh` → `bash tests/run.sh`. Trusted workspaces; no approval. Docs-only: skip.
- **Install:** `FORCE=1 bash scripts/install.sh` (global; merges `hooks.json`). `scripts/uninstall.sh` (owned entries only). Platform: `MacOS/`, `Linux/`, `Windows/`.
- **Docs:** `docs/README.md` (index). Living: ARCHITECTURE, CURATOR, TOOLCHAIN, token-budget, quality-roofs-audit, engineering-system, DECISIONS. Snapshots: `docs/_archive/`.

## Memory

Optional handoff note for unfinished work. Versioned specs under `docs/`. No vendor memory.
