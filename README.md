<div align="center">

  <a href="https://cursor.com">
    <img src="assets/cursor-light.svg#gh-light-mode-only" alt="Cursor" width="56" height="56" />
    <img src="assets/cursor.svg#gh-dark-mode-only" alt="Cursor" width="56" height="56" />
  </a>

  <h1>kleosrules</h1>

  <p><strong>Cursor harness pack — User Rules, companions, skills, Bash hooks, local HANDOFF memory.</strong></p>
  <p>Lean workflow · Ponytail complexity control · Strong agent discipline</p>

  <p>
    <img src="https://img.shields.io/badge/v18.0.0-111827?style=flat&logo=github&logoColor=white" alt="version" />
    <img src="https://img.shields.io/badge/Cursor-000000?style=flat&logo=cursor&logoColor=white" alt="Cursor" />
    <img src="https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash" />
    <img src="https://img.shields.io/badge/license-MIT-2ea44f?style=flat& alt="MIT" />
  </p>

</div>

---

Platform: **macOS** (stock Bash 3.2 + BSD userland fully supported), **Linux**, and **Windows** (PowerShell installer + WSL shim — hooks execute as bash inside WSL). Requires `bash` (v3.2+) and `jq`. No Rust. No Cargo. No Python pack tooling. No MCP dependency for core operation. Canonical hooks live in [`shared/hooks/`](shared/hooks/); platform installers in `MacOS/`, `Linux/`, `Windows/`.

Hooks register **globally** (`~/.cursor/hooks.json`) as the single layer — they spawn with cwd = workspace root, so `HANDOFF.md` and `state/` stay per-project. No per-repo `.cursor/hooks.json` (it fires alongside the global one and doubles every prompt injection).

How it fits Cursor: Cursor is where you build. Chats are focused and finite by design. This pack pairs that with a local `HANDOFF.md` state file so sessions persist across chats. Hooks inject context at start and audit completion. No Obsidian/vault — `HANDOFF.md` is the only memory.

## Setup

macOS — one command (preflights `jq`, fixes permissions, installs rules + skills, registers repo hooks, syncs fleet, verifies):

```bash
git clone https://github.com/kleosr/kleosrules.git
cd kleosrules
bash MacOS/install.sh     # macOS
bash Linux/install.sh     # Linux
```

```powershell
# Windows (PowerShell — hooks run inside WSL via shim; requires wsl + jq inside WSL)
.\Windows\install.ps1
```

Only prerequisite: `jq` (`brew install jq` / `apt-get install jq`; on Windows, inside WSL). Stock macOS bash 3.2 is fully supported — no coreutils, no brew bash.

Manual equivalent:

```bash
chmod +x shared/hooks/*.sh shared/hooks/lib/*.sh scripts/*.sh
bash scripts/doctor.sh        # verify environment
FORCE=1 bash shared/hooks/fleet_sync.sh all
```

Paste `shared/rules/USER-RULES.paste.txt` into Cursor → Settings → Rules → User Rules, start a **new** agent chat, and confirm Hooks loaded the Bash scripts.

## Usage

```bash
# Install / refresh global ~/.cursor hooks, rules, skills + fleet projects
FORCE=1 bash shared/hooks/fleet_sync.sh all

# Sync only / verify only
FORCE=1 bash shared/hooks/fleet_sync.sh sync
FORCE=1 bash shared/hooks/fleet_sync.sh verify

# Doctor (environment + repo health check)
bash scripts/doctor.sh

# Tests (syntax + JSON + hook fixtures)
bash tests/run.sh
```

Loop: **paste rules → fleet_sync install → work under hooks → doctor green → update HANDOFF**. Soft skills guide taste when invoked. Lean size roof (`lean_gate.sh`, soft 120 / hard 300 + >700 rewrite into modules + complexity + coupling + nesting + velocity) denies oversized writes — extract modules or stop; do not fight a deny. `post_tool_use.sh` injects a SCORECARD after dirty writes so the agent sees the mess in-context.

Live `.cursor/` copies were retired: registration is global (`~/.cursor/hooks.json`); edit this pack and re-run `FORCE=1 bash shared/hooks/fleet_sync.sh all`.

Skill routes: `/ponytail` (Native Lean), `/debugging`, `/testing`, `/vernacular`, `/session-handoff`

## Architecture

```
.
├── MacOS/
│   └── install.sh             — macOS installer (brew jq preflight + fleet_sync all)
├── Linux/
│   └── install.sh             — Linux installer (apt/dnf/pacman jq preflight + fleet_sync all)
├── Windows/
│   ├── install.ps1            — PowerShell installer (wsl + jq preflight, copies hooks/rules, writes global hooks.json)
│   └── hooks/
│       └── wsl-shim.ps1       — per-event PowerShell→WSL shim (stdin/stdout passthrough)
├── shared/
│   ├── hooks/                 — canonical Bash hooks, macOS + Linux + WSL safe
│   │   ├── session_start.sh      — inject HANDOFF tail + short DEBERES
│   │   ├── before_submit_prompt.sh — route classify + JOB CARD nudge
│   │   ├── stop_gate.sh           — audit INTENT / OBJECTIVE / Done-when
│   │   ├── lean_gate.sh           — ponytail roof + entropy + velocity (preToolUse)
│   │   ├── pre_tool_use.sh        — selective autonomy gate (thin wrapper)
│   │   ├── post_tool_use.sh       — dirty-file SCORECARD (additional_context)
│   │   ├── after_file_edit.sh     — stamp on-disk writes (Agent + Tab)
│   │   ├── fleet_sync.sh          — install + fleet sync + verify
│   │   ├── fleet_dispatch.sh      — backlog dispatcher
│   │   ├── lib/
│   │   │   ├── common.sh          — shared utilities (root, deny, allow, follow, portable lock)
│   │   │   ├── tool_io.sh         — tool name/path extract + write stamp
│   │   │   ├── scorecard.sh       — post-edit dirty-file message
│   │   │   ├── stop_gate_core.sh  — stop gate logic
│   │   │   └── pre_tool_use_core.sh — autonomy gate logic
│   │   ├── policy/                — intent.json + lean.json (wired only)
│   │   └── hooks.json             — canonical hook registry
│   ├── rules/                 — paste capsule + always-on companions (.mdc)
│   ├── skills/                — on-demand Cursor skills
│   └── config/                — skills list + scan roots + retire lists
├── scripts/                   — doctor.sh, install.sh, sync.sh
├── tests/                     — run.sh + fixtures/
├── docs/                      — ARCHITECTURE, TOOLCHAIN, CURATOR, ADR
├── HANDOFF.md                 — bounded session state (compaction protocol)
├── AGENTS.md                  — map
└── LICENSE                    — MIT
```

Single pack topology — not an app monorepo. Edit this pack and re-run `FORCE=1 bash shared/hooks/fleet_sync.sh all`.

## The loop (injection vs declaration)

1. **Prompt** — you send a message.
2. **Inject (Layer 2)** — `session_start.sh` adds HANDOFF + JOB CARD template (INTENT / OBJECTIVE / tags). `before_submit_prompt.sh` classifies route and may GROUNDING-then-JOB-CARD nudge. `post_tool_use.sh` injects a SCORECARD after dirty writes. Never mutates the user prompt.
3. **Ground then declare (Layer 1)** — Grep/Glob/Read this codebase first (do not invent paths). Then the agent writes `INTENT:` with `OBJECTIVE=<postcondition>` and `edit:`/`NEW:` tags from those hits, before Write.
4. **Audit (Layer 3/4)** — `stop_gate.sh` checks OBJECTIVE quality and Done-when. Files still >700 keep followup until rewrite. If met, clears `/state` and seeds HANDOFF.

## Ponytail / Lean Gate

The lean gate (`lean_gate.sh`) enforces roofs on every `Write|StrReplace`:

| Check | Roof | Action |
|-------|------|--------|
| Soft LOC | 120 | Allow + `agent_message` (prefer subatomic extract) |
| Hard LOC | 300 | Deny growth; steer to subatomic modules |
| Legacy rewrite | >700 | Deny growth; reducing extract allowed; stop followup until rewrite + import update |
| Complexity (decision points) | 50 file / 4+ branch keywords per line | Deny if branching is too dense |
| Coupling (import/include lines) | 10 | Deny if the file knows too much |
| Nesting (brace depth) | 4 | Deny if blocks nest too deep |
| Edit velocity (same file per session) | 15 edits | Deny repeated patching (LOC-reducing edits exempt) |
| Comment ratio | 2% | Deny prose comments on executable source |

Deny recovery: `Read` the blocked file → plan subatomic split → `Write` new modules → `StrReplace` imports → retry. Never use Shell to bypass.

## Testing

```bash
bash tests/run.sh     # syntax + JSON validity + hook fixture tests
bash scripts/doctor.sh  # environment + repo health (16 checks)
```

## What is not supported

- Native Windows without WSL (hooks are Bash; `Windows/install.ps1` + `wsl-shim.ps1` bridge through WSL — untested on this machine, correct-by-construction).
- MCP as a hard dependency (optional only; core works with local HANDOFF).
- Rust gate or pack Python.
- Prompt rewriting via hooks (`updated_input` is banned).

## License

MIT.
