<div align="center">

  <a href="https://cursor.com">
    <img src="assets/cursor-light.svg#gh-light-mode-only" alt="Cursor" width="56" height="56" />
    <img src="assets/cursor.svg#gh-dark-mode-only" alt="Cursor" width="56" height="56" />
  </a>

  <h1>kleosrules</h1>

  <p><strong>Cursor harness pack — User Rules, companions, skills, Bash hooks, local NOW.md memory.</strong></p>
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

Hooks register **globally** (`~/.cursor/hooks.json`) as the single layer. User-hook cwd is `~/.cursor`; `session_start.sh` finds the project via `workspace_roots[0]`. No per-repo `.cursor/hooks.json` (it fires alongside the global one and doubles every prompt injection).

How it fits Cursor: Cursor is where you build. Chats are focused and finite by design. This pack pairs that with a local `NOW.md` so sessions persist across chats. `sessionStart` injects the active sections; submit/shell/read are steel (secrets + shell); `stop` reports Ponytail churn once after the turn. Security: `SECURITY.md`.

## Install / update / uninstall

**Install (global `~/.cursor` only):**

```bash
FORCE=1 bash scripts/install.sh          # or MacOS/install.sh / Linux/install.sh
```

**Update:** Re-run install — idempotent (overwrites hooks/rules/skills/agents; prunes retired names from `shared/config/retired.txt`).

**Uninstall (kleosrules-owned artifacts only):**

```bash
bash scripts/uninstall.sh
```

Removes `~/.cursor/hooks.json` + hooks scripts when the fingerprint matches (`before_submit_prompt.sh`). Removes global `.mdc`, skill symlinks from `skills.txt`, and hunter/cut/prove agents. Does **not** remove unrelated files (e.g. your own `my-custom.mdc`). User Rules paste is manual in Cursor Settings.

**Migration from older layouts:**

- `HANDOFF.md` → `NOW.md` (retired; doctor fails if HANDOFF returns)
- Orphan repo `.cursor/hooks.json` without scripts → healed by `heal_orphan_project_hooks` on sync/project-hooks
- Retired rules (mario-engineering-team, vernacular, …) pruned on install

**Compatibility:** macOS stock Bash 3.2 + Linux Bash 3.2+ + Windows via WSL shim (`Windows/install.ps1`). Native Windows without WSL: **unsupported**. Cloud agents: Lane-A `project-hooks` (3 events: submit/shell/read; no `sessionStart`, no `stop` until a cloud turn is observed to receive `followup_message`).

**Audit docs:** `docs/engineering-rules-audit.md`, `docs/engineering-rules-decision.md`, `docs/research/agent-instructions-research.md`.

## Setup

macOS — one command (preflights `jq`, installs global hooks + rules + skills + agents):

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
FORCE=1 bash scripts/install.sh
```

Paste `shared/rules/USER-RULES.paste.txt` into Cursor → Settings → Rules → User Rules, start a **new** agent chat, and confirm Hooks loaded the Bash scripts.

## Usage

```bash
# Install / refresh global ~/.cursor (hooks, rules, skills, hunter/cut/prove)
FORCE=1 bash scripts/install.sh

# Opt-in: copy project-layer rules to repos listed in shared/config/scan.roots
# (empty by default; SHARED is empty — types.mdc is global alwaysApply)
FORCE=1 bash shared/hooks/fleet_sync.sh sync
FORCE=1 bash shared/hooks/fleet_sync.sh verify

# Doctor (environment + repo health check)
bash scripts/doctor.sh

# Tests (syntax + JSON + hook fixtures)
bash tests/run.sh
```

Loop: **paste rules → `FORCE=1 bash scripts/install.sh` → work under five hooks → doctor green → update NOW.md**. Soft skills guide taste when invoked. Ponytail 300 LOC is law in `.mdc`. `stop.sh` checks unrequested rewrite (>50% of a tracked src file, ≥80 LOC), mass reindent, and duplicate helper. Registered steel is secrets + shell deny + NOW.md + stop churn gate.

Live registration is global (`~/.cursor/hooks.json`, native `./hooks/*.sh`). Edit this pack and re-run `FORCE=1 bash scripts/install.sh`. `sync` does not install or remove other repos’ `.cursor/hooks`.

Skill routes: `/ponytail`, `/debugging`, `/testing`, `/complexity`, `/now`. Review agents: `hunter`, `cut`, `prove`.

## Architecture

```
.
├── MacOS/
│   └── install.sh             — macOS installer (jq preflight + fleet_sync install)
├── Linux/
│   └── install.sh             — Linux installer (jq preflight + fleet_sync install)
├── Windows/
│   ├── install.ps1            — PowerShell installer (wsl + jq preflight, copies hooks/rules, writes global hooks.json)
│   └── hooks/
│       └── wsl-shim.ps1       — per-event PowerShell→WSL shim (stdin/stdout passthrough)
├── shared/
│   ├── hooks/                 — canonical Bash hooks, macOS + Linux + WSL safe
│   │   ├── session_start.sh      — inject NOW.md active sections
│   │   ├── before_submit_prompt.sh — secret-prompt block (failClosed:false)
│   │   ├── before_shell.sh        — destructive / source-write deny
│   │   ├── before_read_file.sh    — secret path deny
│   │   ├── stop.sh                — Ponytail churn followup (loop_limit 1)
│   │   ├── fleet_sync.sh          — install + verify; sync is opt-in
│   │   ├── lib/
│   │   │   ├── common.sh          — shared utilities (root, deny, allow, continue)
│   │   │   ├── shell_gate.sh      — before_shell policy
│   │   │   └── diff_gate.sh       — stop.sh rewrite / format / duplicate
│   │   ├── policy/                — *.ere deny lists
│   │   └── hooks.json             — canonical 5-event registry
│   ├── rules/                 — paste capsule + always-on companions (.mdc)
│   ├── skills/                — on-demand Cursor skills
│   ├── agents/                — hunter, cut, prove (installed to ~/.cursor/agents)
│   └── config/                — skills list + scan roots + retire lists
├── scripts/                   — doctor.sh, install.sh, uninstall.sh, sync.sh
├── tests/                     — run.sh + fixtures/
├── docs/                      — ARCHITECTURE, TOOLCHAIN, CURATOR, ADR
├── NOW.md                     — bounded session state (compaction protocol)
├── SECURITY.md                — pnpm + cybersecurity SSOT
├── AGENTS.md                  — map
└── LICENSE                    — MIT
```

Single pack topology — not an app monorepo. Edit this pack and re-run `FORCE=1 bash scripts/install.sh`.

## The loop (injection vs declaration)

1. **Prompt** — you send a message.
2. **Inject (Layer 2)** — `session_start.sh` adds the NOW.md active sections. `before_submit_prompt.sh` may block a secret-looking prompt. Never mutates the user prompt.
3. **Ground then declare (Layer 1)** — Grep/Glob/Read this codebase first (do not invent paths). Then one or two sentences before Write: what will be true, which files, how you will prove it. That is `.mdc` law, not a hook followup.
4. **Steel** — `before_shell.sh` and `before_read_file.sh` deny a small list. `stop.sh` may follow up once on churn. Conversation police is not registered.

## Ponytail

Roofs live in `ponytail.mdc` + skill (soft ~80 / split before 120 / hard 300 / never 500 / >700 rewrite). `stop.sh` is the registered lean hook for **churn only** (rewrite ratio, mass reindent, duplicate helper) — not file size. Complexity is `complexity.mdc` + lint, not a hook deny.

Recovery: `Read` the file → plan split → `Write` new modules → `StrReplace` imports → retry. Never use Shell to bypass.

## Testing

```bash
bash tests/run.sh     # syntax + JSON validity + hook fixture tests
bash scripts/doctor.sh  # environment + repo health (16 checks)
```

## What is not supported

- Native Windows without WSL (hooks are Bash; `Windows/install.ps1` + `wsl-shim.ps1` bridge through WSL — untested on this machine, correct-by-construction).
- MCP as a hard dependency (optional only; core works with local NOW.md).
- Rust gate or pack Python.
- Prompt rewriting via hooks (`updated_input` is banned).

## License

MIT.
