# Hooks Architecture Decision Record (ADR)

Date: 2026-07-30 (updated 2026-08-04)
Status: **Accepted (supersedes 2026-07-29 Rust ADR)**
Deciders: kleosr (system architect)
Context: V2 harness — Bash hooks + local HANDOFF brain. No Rust kleos-gate. No pack Python. No MCP core dependency.

---

## Decision

**Bash event hooks are the definitive hooks surface for kleosr V2.**

| Script | Event | Job |
|--------|-------|-----|
| `session_start.sh` | sessionStart | Inject HANDOFF tail + duties (`additional_context`) |
| `before_submit_prompt.sh` | beforeSubmitPrompt | Route classify + state writes; allow/block via `continue` (not context) |
| `stop_gate.sh` | stop | Audit INTENT / Done-when from `transcript_path` (or inline arrays); followup or accept |
| `lean_gate.sh` | preToolUse (Write\|Edit\|…) | Deny files over roof; complexity + coupling + nesting + velocity (`permission`) |
| `pre_tool_use.sh` | preToolUse (Write\|…\|Shell\|Bash) | Selective autonomy: topology + destructive blocks |
| `before_shell.sh` | beforeShellExecution | Destructive shell gating (`permission`) |
| `before_mcp.sh` | beforeMCPExecution | Dangerous MCP pattern deny (`permission`) |
| `before_read_file.sh` | beforeReadFile + beforeTabFileRead | Secret path deny |
| `fleet_sync.sh` | install/sync/project-hooks/verify | Home + fleet + optional cloud Lane-A |

### Architecture (V18 refactor)

Event hook entrypoints are **thin wrappers** (≤80 LOC) that source core logic from `shared/hooks/lib/`:

| Wrapper | Lib | LOC (wrapper) |
|---------|-----|---------------|
| `stop_gate.sh` | `lib/stop_gate_core.sh` | 4 |
| `pre_tool_use.sh` | `lib/pre_tool_use_core.sh` | 4 |
| `lean_gate.sh` | (self-contained, ≤80) | 79 |
| `before_submit_prompt.sh` | (self-contained, ≤80) | 49 |
| `session_start.sh` | `lib/common.sh` | 13 |

Shared utilities in `lib/common.sh`: root resolution, state dir, deny/allow/followup/context emitters.

Hard bans: never `updated_input`; never reintroduce `hooks/bin/kleos-gate` or pack Python; each event hook ≤80 LOC; fail-closed where registered; no MCP core dependency; no GNU-only utils (`flock`, `mapfile`, `realpath`, `stat -c`, awk `\<` boundaries) — hooks must run on stock macOS bash 3.2 + BSD userland. **Cursor-native**: hook stdout uses `permission`/`user_message`/`agent_message` (deny-allow), `additional_context` (sessionStart), `continue` (beforeSubmitPrompt), `followup_message` (stop) — never Claude shapes (`hookSpecificOutput`/`permissionDecision`) and never legacy `action`/`additionalContext`.

## Why not Rust

The prior ADR preferred a typed Rust binary. V2 rejects that pack: install entropy, Cargo toolchain, and binary drift outweighed typed-policy gains for this harness. Soft law (paste + companions + skills) plus thin Bash muscles is enough. `HANDOFF.md` is the durable brain. Hooks only inject and audit markers.

## Policy SSOT (wired only)

| File | Consumer |
|------|----------|
| `shared/hooks/policy/intent.json` | `before_submit_prompt.sh`, `stop_gate.sh` |
| `shared/hooks/policy/lean.json` | `lean_gate.sh` |

No orphan ask/deny JSON from the retired gate. Secrets stay out of paste, hooks, and chat.

## Hook config (canonical)

Single source: `shared/hooks/hooks.json`. `fleet_sync.sh` generates the global `~/.cursor/hooks.json` from it (path rewriting only); `Windows/install.ps1` generates the Windows equivalent with PowerShell→WSL shim commands.

**2026-08-10 — single registration layer, GLOBAL.** Local IDE: registration lives in `~/.cursor/hooks.json`; default sync removes per-repo hooks so `sessionStart` DUTY is not doubled.

**2026-08-11 — cloud Lane-A.** Cloud agents ignore `~/.cursor`. `CLOUD=1 bash shared/hooks/fleet_sync.sh project-hooks` installs `hooks.cloud.json` (lean/shell/read/tab/mcp/submit/stop) with **no sessionStart**. Local+project coexistence: steel gates may double-fire (idempotent); DUTY injection stays global-only.

### preToolUse matcher overlap (intentional)

Two preToolUse hooks fire for Cursor `Write` (plus Claude-compat edit aliases):

| Hook | Matcher | Responsibility |
|------|---------|----------------|
| `lean_gate.sh` | `Write\|Edit\|MultiEdit\|StrReplace` | Size roof (700 LOC), complexity, coupling, nesting, velocity |
| `pre_tool_use.sh` | `Write\|Edit\|MultiEdit\|StrReplace\|Shell\|Bash` | Topology sandbox, destructive content, destructive Shell |

This is intentional: `lean_gate` enforces complexity discipline; `pre_tool_use` enforces autonomy/safety. Both run independently — a write must pass both gates. Destructive shell commands are also gated by `beforeShellExecution` → `before_shell.sh` (Cursor-native shell hook; `failClosed: true`).

## Residual (class J)

- Semantic Done-when quality: agent judgment + `agent.mdc` autonomous loop
- Shell destructive actions: `before_shell.sh` + `pre_tool_use.sh` block destructive patterns; Cursor native permissions / user confirm as backstop
