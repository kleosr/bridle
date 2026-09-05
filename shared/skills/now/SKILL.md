---
name: now
description: >
  Write or resume NOW.md. Use when switching chats, pausing a feature, or
  the user mentions NOW.md, session continuity, or handoff.
---

# Now

Persist state in the **repo**. Cursor chats die.

## Path

One file: `NOW.md` at repo root.

## Resume

1. Read `NOW.md` if it exists.
2. Re-run listed TOOLCHAIN/CI commands before claiming prior work is green.
3. Do **one** Next action unless the user said autopilot/`sigue`.
4. Do not re-discover the whole codebase; open only paths listed or needed.

## Update

Keep Now, State, Limits, Proof, Next. Compact into Archived when active sections exceed ~150 lines. English labels. No secrets.

## Rules

- Assessment-only until the user asked for changes (per `agent.mdc`).
- Never invent residual features; append open items here.
- Pair with testing for feature execution; debugging if Next is ambiguous.
