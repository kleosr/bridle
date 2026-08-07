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
| `session_start.sh` | sessionStart | Inject HANDOFF tail + duties (`additionalContext`) |
| `before_submit_prompt.sh` | beforeSubmitPrompt | Route classify + thin INTENT duty (`additionalContext`) |
| `stop_gate.sh` | stop | Audit INTENT / Done-when; followup or accept + seed HANDOFF |
| `lean_gate.sh` | preToolUse (Write\|Edit\|MultiEdit\|StrReplace) | Deny files over roof; complexity + coupling + nesting + velocity check |
| `pre_tool_use.sh` | preToolUse (Write\|Edit\|MultiEdit\|StrReplace\|Bash) | Selective autonomy: topology + destructive blocks |
| `fleet_sync.sh` | install/sync/verify | Home + fleet wiring |

### Architecture (V18 refactor)

Event hook entrypoints are **thin wrappers** (≤80 LOC) that source core logic from `hooks/lib/`:

| Wrapper | Lib | LOC (wrapper) |
|---------|-----|---------------|
| `stop_gate.sh` | `lib/stop_gate_core.sh` | 4 |
| `pre_tool_use.sh` | `lib/pre_tool_use_core.sh` | 4 |
| `lean_gate.sh` | (self-contained, ≤80) | 79 |
| `before_submit_prompt.sh` | (self-contained, ≤80) | 49 |
| `session_start.sh` | `lib/common.sh` | 13 |

Shared utilities in `lib/common.sh`: root resolution, state dir, deny/allow/followup/context emitters.

Hard bans: never `updated_input`; never reintroduce `hooks/bin/kleos-gate` or pack Python; each event hook ≤80 LOC; fail-closed where registered; no MCP core dependency. **Cursor-only**: hook stdout is Cursor JSON (`action`/`user_message`, `additionalContext`, `followup_message`) — never emit Claude Code shapes (`hookSpecificOutput`/`permissionDecision`).

## Why not Rust

The prior ADR preferred a typed Rust binary. V2 rejects that pack: install entropy, Cargo toolchain, and binary drift outweighed typed-policy gains for this harness. Soft law (paste + companions + skills) plus thin Bash muscles is enough. `HANDOFF.md` is the durable brain. Hooks only inject and audit markers.

## Policy SSOT (wired only)

| File | Consumer |
|------|----------|
| `hooks/policy/intent.json` | `before_submit_prompt.sh`, `stop_gate.sh` |
| `hooks/policy/lean.json` | `lean_gate.sh` |

No orphan ask/deny JSON from the retired gate. Secrets stay out of paste, hooks, and chat.

## Hook config (canonical)

Single source: `hooks/hooks.json`. `fleet_sync.sh` generates per-repo `.cursor/hooks.json` and `~/.cursor/hooks.json` from it (path rewriting only).

### preToolUse matcher overlap (intentional)

Two preToolUse hooks fire for `Write|Edit|MultiEdit|StrReplace`:

| Hook | Matcher | Responsibility |
|------|---------|----------------|
| `lean_gate.sh` | `Write\|Edit\|MultiEdit\|StrReplace` | Size roof (700 LOC), complexity, coupling, nesting, velocity |
| `pre_tool_use.sh` | `Write\|Edit\|MultiEdit\|StrReplace\|Bash` | Topology sandbox, destructive content, destructive Bash |

This is intentional: `lean_gate` enforces complexity discipline; `pre_tool_use` enforces autonomy/safety. Both run independently — a write must pass both gates. For `Bash`, only `pre_tool_use` fires (no size check on shell commands).

## Residual (class J)

- Semantic Done-when quality: agent judgment + `agent.mdc` autonomous loop
- Shell destructive actions: `pre_tool_use.sh` blocks destructive patterns; Cursor native permissions / user confirm as backstop
