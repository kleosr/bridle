# AGENTS.md — Repository Agent Handbook

Navigator for agents in this pack. Do not paste this file into Task briefs.

Law lives elsewhere. This file is a map.

## Law

- **Charter (User Rules paste, cloud floor):** `shared/rules/USER-RULES.paste.txt`
- **Roofs (caps and quality floors):** `shared/rules/complexity.mdc`, `ponytail.mdc`, `testing.mdc`, `types.mdc`
- **Map of those numbers:** `docs/quality-roofs-audit.md`
- **Why this file is thin:** `docs/astra-slim.md`
- **Steel (do not slim):** five registered hooks — `session_start.sh`, `before_submit_prompt.sh`, `before_shell.sh`, `before_read_file.sh`, `stop.sh`
- **Secrets:** `SECURITY.md`. Never put secret values in paste, hooks, chat, or `NOW.md`.

## Pack

- Brain = `NOW.md`. Muscle = the five hooks. Local install only (`FORCE=1 bash scripts/install.sh` → `~/.cursor`). Never Lane-A into this pack.
- No Rust kleos-gate. No pack Python. MCP is optional, never core.
- Output: never `updated_input` (no `preToolUse`). `sessionStart` → `additional_context`. `beforeSubmitPrompt` → `continue`. `stop` → one `followup_message`.

## Skills (on demand)

Stored in `shared/skills/` (not `.agents/skills`). Read `SKILL.md` only when the task matches. Description lines are routers; detail files load after.

- Core: `ponytail`, `debugging`, `testing`, `complexity`, `now`
- Design: `design-stack` → one of `premium-ui-craft`, `landing-page-design`, `redesign-existing-projects`, `ux-web-research`
- Specialists: `shared/agents/hunter.md`, `cut.md`, `prove.md`

## Workflows

- **Verify:** `chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh` → `bash -n` those scripts → `bash scripts/doctor.sh` → `bash tests/run.sh`
- **Install:** `FORCE=1 bash scripts/install.sh` (global). `scripts/uninstall.sh` (fingerprinted). Platform: `MacOS/`, `Linux/`, `Windows/`. Fleet sync opt-in via empty-by-default `shared/config/scan.roots`.
- **Docs:** `docs/ARCHITECTURE.md`, `docs/CURATOR.md`, `docs/TOOLCHAIN.md` (hook ≤80 LOC), `SECURITY.md`.

## Memory

`NOW.md` (Now, State, Limits, Proof, Next, Archived; compact ~150 lines). Versioned specs under `docs/`. No vendor memory.
