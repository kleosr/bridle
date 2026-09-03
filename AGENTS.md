# AGENTS.md — Repository Agent Handbook

Single source of truth for coding agents operating in this repository.

## Rules

- **Law vs Handbook**: Law lives in registered hook scripts, user rules paste (`shared/rules/USER-RULES.paste.txt`), and rules (`shared/rules/*.mdc`). This file is the canonical handbook and operational contract.
- **Pack Core**: kleosrules V2 Bash hooks + local `NOW.md` memory. Brain = `NOW.md`. Muscle = five registered hook scripts (`session_start.sh`, `before_submit_prompt.sh`, `before_shell.sh`, `before_read_file.sh`, `stop.sh`).
- **No Rust / No Pack Python / No Core MCP**: No Rust kleos-gate or pack Python tooling. MCP is optional, never a core dependency.
- **Install Scope**: Local install is global-only (`FORCE=1 bash scripts/install.sh` writes `~/.cursor`). Never install Lane-A into this pack.
- **Output Protocol**: Never emit `updated_input` (preToolUse is not registered). Inject state via `additional_context` on `sessionStart`, control flow via `continue` on `beforeSubmitPrompt`, one bounded `followup_message` on `stop`.
- **Security & Secrets**: Follow `SECURITY.md` (pnpm supply chain and cybersecurity SSOT). Never put secret values in paste, hooks, chat, or `NOW.md`.

## Skills

Reusable task recipes and specialist definitions for this pack:

- **Skills Location**: Stored in `shared/skills/` (not `.agents/skills`).
- **Active Skills**:
  - `shared/skills/ponytail/`: Native Lean quality bar, code roofs, split recovery.
  - `shared/skills/debugging/`: Systematic reproduce → hypothesis → evidence → fix.
  - `shared/skills/testing/`: Test-first red-green-refactor; verify toolchain before Done.
  - `shared/skills/complexity/`: Cyclomatic cap (repo lint or 10); extract until lint passes.
  - `shared/skills/now/`: Local session state management in `NOW.md`.
  - `shared/skills/design-stack/`, `premium-ui-craft/`, `landing-page-design/`, `redesign-existing-projects/`, `ux-web-research/`: UI and design craft.
- **Specialist Review Agents**:
  - `shared/agents/hunter.md`: Pre-PR vulnerability and security audit pass.
  - `shared/agents/cut.md`: Dependency trimming and dead code removal.
  - `shared/agents/prove.md`: Independent verification, real test suite, and audit check.

## Workflows

Canonical paths and operational procedures across development cycles:

- **Verification Loop**:
  1. `chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh`
  2. `bash -n shared/hooks/*.sh shared/hooks/lib/*.sh`
  3. `bash scripts/doctor.sh` — 16 environment and repository health checks.
  4. `bash tests/run.sh` — syntax, JSON validity, and hook fixtures.
- **Install & Sync**:
  - `FORCE=1 bash scripts/install.sh` — writes global `~/.cursor` (hooks, rules, skills, agents).
  - `scripts/uninstall.sh` — remove kleosrules-owned `~/.cursor` artifacts (fingerprinted).
  - Platform installers: `MacOS/install.sh`, `Linux/install.sh`, `Windows/install.ps1` (+ `Windows/hooks/wsl-shim.ps1`).
  - `scripts/sync.sh` / `shared/hooks/fleet_sync.sh` — opt-in fleet sync via `shared/config/scan.roots` (empty by default).
- **Core Architecture & Policies**:
  - `docs/ARCHITECTURE.md`: 5 layers and deterministic containment model.
  - `docs/CURATOR.md`: Context curation and pre-write plain-sentence declaration.
  - `docs/TOOLCHAIN.md`: Toolchain requirements (Bash >= 3.2, jq) and size roofs (<=80 LOC per hook).
  - `SECURITY.md`: Cybersecurity rules and pnpm configuration standards.

## Memory

Agent memory in this repository is purely local and file-backed:

- **Session State**: `NOW.md` is the local bounded session memory (format: Now, State, Limits, Proof, Next, Archived). Compaction protocol triggers when active sections exceed ~150 lines.
- **Versioned Repository Memory**: Documented specifications and architectural decision records live under `docs/`:
  - `docs/ARCHITECTURE.md`
  - `docs/CURATOR.md`
  - `docs/TOOLCHAIN.md`
  - `docs/DECISIONS/hooks-architecture.md`
  - `docs/engineering-rules-audit.md`, `docs/engineering-rules-decision.md`: audit inventory and architecture decision (2026-09).
  - `docs/runtime-grounding-audit.md`, `docs/engineering-system.md`: lifecycle matrix, runtime probes, GROUND→STOP loop (2026-09-03).
- **Vendor Independence**: No vendor memory features or proprietary remote context dependencies.
