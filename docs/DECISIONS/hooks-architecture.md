# Hooks Architecture Decision Record (ADR)

Date: 2026-07-30
Status: **Accepted (supersedes 2026-07-29 Rust ADR)**
Deciders: kleosr (system architect)
Context: V2 harness — Bash hooks + Obsidian brain. No Rust kleos-gate. No pack Python.

---

## Decision

**Bash event hooks are the definitive hooks surface for kleosr V2.**

| Script | Event | Job |
|--------|-------|-----|
| `session_start.sh` | sessionStart | Inject amnesia roofs + HANDOFF tail (`additional_context`) |
| `before_submit_prompt.sh` | beforeSubmitPrompt | Route classify + thin INTENT duty (`additional_context`) |
| `stop_gate.sh` | stop | Audit INTENT / Done-when; followup or accept + write-back nudge |
| `lean_gate.sh` | preToolUse (Write\|StrReplace) | Deny files over `policy/lean.json` `file_loc_max` |
| `fleet_sync.sh` | install/sync/verify | Home + fleet wiring |

Hard bans: never `updated_input`; never reintroduce `hooks/bin/kleos-gate` or pack Python; each event hook ≤80 LOC; fail-closed where registered.

## Why not Rust

The prior ADR preferred a typed Rust binary. V2 rejects that pack: install entropy, Cargo toolchain, and binary drift outweighed typed-policy gains for this harness. Soft law (paste + companions + skills) plus thin Bash muscles is enough. Obsidian is the durable graph; hooks only inject and audit markers.

## Policy SSOT (wired only)

| File | Consumer |
|------|----------|
| `hooks/policy/intent.json` | `before_submit_prompt.sh`, `stop_gate.sh` |
| `hooks/policy/lean.json` | `lean_gate.sh` |

No orphan ask/deny JSON from the retired gate. Secrets stay out of paste, hooks, and chat.

## Residual (class J)

- Semantic Done-when quality: agent judgment + `agent.mdc` autonomous loop
- Obsidian write-back completeness: soft roofs + stop accept followup
- Shell destructive actions: Cursor native permissions / user confirm — not pack gate
