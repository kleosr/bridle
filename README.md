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

Hooks register **globally** (`~/.cursor/hooks.json`) as the single layer. User-hook cwd is `~/.cursor`; `session_start.sh` finds the project via `workspace_roots[0]`. No per-repo `.cursor/hooks.json` for local work (it fires alongside the global one and doubles every prompt injection). Cursor Cloud Agents cannot see `~/.cursor`, so for a repo that needs steel in the cloud use `CLOUD=1 TARGET_REPO=<path> bash shared/hooks/fleet_sync.sh project-hooks` (writes `hooks.cloud.json`: shell/read/submit, no sessionStart). Never into this pack.

Consumers: Cursor only. There is no Claude Code, Codex, or Copilot consumer, so there is no `CLAUDE.md`, `.cursorrules`, or nested `AGENTS.md`; the single root `AGENTS.md` is the repository handbook. Decision record: [`docs/engineering-rules-decision.md`](docs/engineering-rules-decision.md); audit: [`docs/engineering-rules-audit.md`](docs/engineering-rules-audit.md).

How it fits Cursor: Cursor is where you build. Chats are focused and finite by design. This pack pairs that with a local `NOW.md` so sessions persist across chats. `sessionStart` injects the active sections; the other three hooks are steel (secrets + shell). Security: `SECURITY.md`.

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

# Opt-in: copy types.mdc to repos listed in shared/config/scan.roots (empty by default)
FORCE=1 bash shared/hooks/fleet_sync.sh sync
FORCE=1 bash shared/hooks/fleet_sync.sh verify

# Doctor (environment + repo health check)
bash scripts/doctor.sh

# Tests (syntax + JSON + hook fixtures)
bash tests/run.sh

# Uninstall: removes only kleosrules-owned files from ~/.cursor (hooks.json, hooks/, the ten
# pack rules, pack skill symlinks, hunter/cut/prove). Foreign rules, skills, agents stay.
bash scripts/uninstall.sh
```

Update = `git pull` then `FORCE=1 bash scripts/install.sh` again; install is idempotent (running it twice yields the same `~/.cursor` tree) and prunes retired names listed in `shared/config/retired*.txt`. Migrating from ≤ v18: re-run install (it stops writing `~/.cursor/state`), then delete any leftover `state/` directory the old `session_start.sh` created in your workspaces or `~/.cursor` — nothing reads it.

Loop: **paste rules → `FORCE=1 bash scripts/install.sh` → work under four hooks → doctor green → update NOW.md**. Soft skills guide taste when invoked. Ponytail roofs live in `.mdc`. Registered steel is secrets + shell deny + NOW.md.

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
│   │   ├── fleet_sync.sh          — install | verify | uninstall | sync (opt-in) | project-hooks (cloud)
│   │   ├── lib/
│   │   │   ├── common.sh          — runtime: root resolution, NOW.md extraction, emit_* JSON
│   │   │   ├── shell_gate.sh      — runtime: before_shell decision tables
│   │   │   ├── fleet_install.sh   — installer: copy/prune/uninstall ~/.cursor
│   │   │   ├── fleet_sync_repos.sh — installer: rules, skills, agents, opt-in sync
│   │   │   ├── fleet_scan.sh      — installer: config parsing, discovery
│   │   │   ├── fleet_verify.sh    — installer: post-install smoke
│   │   │   └── windows_hooks_rewrite.jq — installer: WSL shim rewrite of hooks.json
│   │   ├── policy/                — secret_paths.ere, secret_tokens.ere (grep -E -f)
│   │   ├── hooks.json             — canonical 4-event user registry
│   │   └── hooks.cloud.json       — 3-event project registry for cloud agents
│   ├── rules/                 — paste capsule + always-on companions (.mdc)
│   ├── skills/                — on-demand Cursor skills
│   ├── agents/                — hunter, cut, prove (installed to ~/.cursor/agents)
│   └── config/                — skills list + scan roots + retire lists
├── scripts/                   — doctor.sh, install.sh, uninstall.sh, sync.sh
├── tests/                     — run.sh + fixtures/ + audit.sh (branch fixtures)
├── docs/                      — ARCHITECTURE, TOOLCHAIN, CURATOR, ADR, engineering-rules-{audit,decision}, research/
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
4. **Steel** — `before_shell.sh` and `before_read_file.sh` deny a small list. Conversation police is not registered.

## Ponytail

Roofs live in `ponytail.mdc` + skill. There is **no** registered lean hook. The model follows the ladder (soft ~80 / split before 120 / hard 300 / >700 rewrite). Complexity is `complexity.mdc` + lint, not a hook deny.

Recovery: `Read` the file → plan split → `Write` new modules → `StrReplace` imports → retry. Never use Shell to bypass.

## Testing

```bash
bash tests/run.sh       # syntax + JSON validity + hook fixture tests (allow/deny/ask, malformed payload, missing policy, broken jq, install×2, uninstall)
bash scripts/doctor.sh  # environment + repo health; checksums ~/.cursor/hooks against the pack when installed
```

Platform evidence: CI runs the full suite on `ubuntu-latest` and `macos-latest` (stock `/bin/bash` 3.2). Windows/WSL is **not** exercised by CI; `Windows/install.ps1`, `uninstall.ps1`, and `hooks/wsl-shim.ps1` are correct-by-construction only.

## What is not supported

- Native Windows without WSL (hooks are Bash; `Windows/install.ps1` + `wsl-shim.ps1` bridge through WSL — untested in CI, correct-by-construction).
- Claude Code / `CLAUDE.md`, Codex, Copilot instruction files: not consumed by anything here. Add one only with a verified consumer (see `docs/engineering-rules-decision.md`).
- MCP as a hard dependency (optional only; core works with local NOW.md).
- Rust gate or pack Python.
- Prompt rewriting via hooks (`updated_input` is banned).

## License

MIT.
