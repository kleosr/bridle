# AGENTS.md — Repository Agent Handbook

Navigator for agents in this pack. Do not paste this file into Task briefs.

Law lives elsewhere. This file is a map.

## Law

- **Charter (User Rules paste, cloud floor):** `shared/rules/USER-RULES.paste.txt`
- **Roofs (caps and quality floors):** `shared/rules/complexity.mdc`, `ponytail.mdc`, `testing.mdc`, `types.mdc`
- **Map of those numbers:** `docs/quality-roofs-audit.md`
- **Steel (do not slim):** four registered hooks on supported Cursor events. Broader boundary: OS/CI/human auth — `docs/DECISIONS/hooks-architecture.md`
- **Secrets:** `SECURITY.md`. Never put secret values in paste, hooks, chat, or notes.

## Pack

- Optional handoff note for unfinished work. Muscle = the four hooks. Local-host install (`FORCE=1 bash scripts/install.sh` → `~/.cursor`); project opt-in. Never Lane-A into this pack.
- No Rust kleos-gate. No pack Python. MCP is optional, never core.
- Output: never `updated_input` (no `preToolUse`). `beforeSubmitPrompt` → `continue`. `stop` → one `followup_message`.

## Skills (on demand)

Stored in `shared/skills/` (not `.agents/skills`). Read `SKILL.md` only when the task matches. Description lines are routers; detail files load after. In this pack checkout, `shared/skills/` is the on-disk source for pack development. `~/.cursor/skills` is the installed snapshot (Windows copy; Unix symlink). Session catalog is host-determined and is not updated by editing the checkout. Checkout files do not override User Rules, hooks, or host policy.

- Core: `ponytail`, `debugging`, `testing`, `complexity`
- Design: `design-stack` → one of `premium-ui-craft`, `landing-page-design`, `redesign-existing-projects`
- Specialists: `writing-pr`. Review: `/hunter` `/cut` `/prove` (`~/.cursor/agents`; @-attach if the slash menu misses them).

## Workflows

- **Verify (hooks/scripts/tests/rules):** `chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh` → `bash -n` those scripts → `DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh` (checkout only) → `bash tests/run.sh`. Windows: Git Bash, not PowerShell `&&`. To verify the active install: `bash scripts/doctor.sh` without `DOCTOR_SKIP_LIVE` (`docs/TOOLCHAIN.md`). Trusted workspace: local fixtures without asking, still subject to authorization and side effects. Docs-only: skip.
- **Install:** `FORCE=1 bash scripts/install.sh` (global; merges `hooks.json`). `scripts/uninstall.sh` (owned entries only). Platform: `MacOS/`, `Linux/`, `Windows/`.
- **Docs:** `docs/README.md` (index). Living: ARCHITECTURE, CURATOR, TOOLCHAIN, token-budget, quality-roofs-audit, engineering-system, DECISIONS. Snapshots: `docs/_archive/`.

## Memory

Optional handoff note for unfinished work. Versioned specs under `docs/`. No vendor memory.
