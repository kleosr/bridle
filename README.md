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

Platform: **Linux or WSL**. Requires `bash` (v4+) and `jq`. No Rust. No Cargo. No Python pack tooling. No MCP dependency for core operation.

How it fits Cursor: Cursor is where you build. Chats are focused and finite by design. This pack pairs that with a local `HANDOFF.md` state file so sessions persist across chats. Hooks inject context at start and audit completion. Obsidian MCP is **optional** — wire it only if you want graph-based durable memory.

## Setup

```bash
git clone https://github.com/kleosr/kleosrules.git
cd kleosrules
chmod +x hooks/*.sh hooks/lib/*.sh scripts/*.sh
bash scripts/doctor.sh        # verify environment
FORCE=1 bash hooks/fleet_sync.sh all
```

Paste `user-rules/USER-RULES.paste.txt` into Cursor → Settings → Rules → User Rules, start a **new** agent chat, and confirm Hooks loaded the Bash scripts.

## Usage

```bash
# Install / refresh ~/.cursor hooks, rules, skills + fleet projects
FORCE=1 bash hooks/fleet_sync.sh all

# Sync only / verify only
FORCE=1 bash hooks/fleet_sync.sh sync
FORCE=1 bash hooks/fleet_sync.sh verify

# Doctor (environment + repo health check)
bash scripts/doctor.sh

# Tests (syntax + JSON + hook fixtures)
bash tests/run.sh
```

Loop: **paste rules → fleet_sync install → work under hooks → doctor green → update HANDOFF**. Soft skills guide taste when invoked. Lean size roof (`lean_gate.sh`, 700 LOC + entropy + velocity) denies oversized writes — rewrite or stop; do not fight a deny.

Skill routes: lean → `/ponytail`; dialect → `/vernacular`; vault (optional) → `/obsidian-memory`; AST → `/codebase-memory`.

## Architecture

```
.
├── hooks/
│   ├── session_start.sh      — inject HANDOFF tail + duties
│   ├── before_submit_prompt.sh — route classify + INTENT duty
│   ├── stop_gate.sh           — audit INTENT / Done-when (thin wrapper)
│   ├── lean_gate.sh           — ponytail roof + entropy + velocity (preToolUse)
│   ├── pre_tool_use.sh        — selective autonomy gate (thin wrapper)
│   ├── fleet_sync.sh          — install + fleet sync + verify
│   ├── fleet_dispatch.sh      — backlog dispatcher
│   ├── lib/
│   │   ├── common.sh          — shared utilities (root, deny, allow, follow)
│   │   ├── stop_gate_core.sh  — stop gate logic
│   │   └── pre_tool_use_core.sh — autonomy gate logic
│   ├── policy/                — intent.json + lean.json (wired only)
│   └── hooks.json             — canonical hook registry
├── project-rules/             — always-on companions (.mdc)
├── user-rules/                — paste capsule + option-c-core mirror
├── skills/                    — on-demand Cursor skills
├── config/                    — skills list + scan roots + retire lists
├── scripts/                   — doctor.sh, install.sh, sync.sh
├── tests/                     — run.sh + fixtures/
├── docs/                      — ARCHITECTURE, TOOLCHAIN, CURATOR, ADR
├── HANDOFF.md                 — bounded session state (compaction protocol)
├── AGENTS.md                  — map
└── LICENSE                    — MIT
```

Single pack topology — not an app monorepo. Live `.cursor/` copies are sync destinations; edit this pack and re-run `FORCE=1 bash hooks/fleet_sync.sh all`.

## The loop (injection vs declaration)

1. **Prompt** — you send a message.
2. **Inject (Layer 2)** — `before_submit_prompt.sh` adds duties with `additional_context`. It does not mutate the user prompt.
3. **Declare (Layer 1)** — the agent writes `INTENT:` and `Done-when:` in chat before tools run.
4. **Audit (Layer 3/4)** — `stop_gate.sh` checks Done-when. If unmet, another pass. If met, clears `/state` and seeds HANDOFF.

## Ponytail / Lean Gate

The lean gate (`lean_gate.sh`) enforces three dimensions on every `Write|Edit|MultiEdit|StrReplace`:

| Check | Roof | Action |
|-------|------|--------|
| Projected LOC | 700 (hard) | Deny if post-edit file exceeds |
| Entropy (flow-control keywords) | 30 per edit | Deny if complexity too high |
| Edit velocity (same file per session) | 15 edits | Deny if repeated patching of bloated file |

Deny recovery: `Read` the blocked file → plan split → `Write` new modules → `StrReplace` imports → retry. Never use Shell to bypass.

## Testing

```bash
bash tests/run.sh     # syntax + JSON validity + hook fixture tests
bash scripts/doctor.sh  # environment + repo health (16 checks)
```

## What is not supported

- Native Windows (PowerShell port welcome).
- MCP as a hard dependency (optional only; core works with local HANDOFF).
- Rust gate or pack Python.
- Prompt rewriting via hooks (`updated_input` is banned).

## License

MIT.
