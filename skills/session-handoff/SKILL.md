---
name: session-handoff
description: >-
  Write or resume a structured HANDOFF.md for multi-session agent work.
  Use when continuing tomorrow, switching chats/models, pausing a feature,
  or the user mentions handoff, HANDOFF, or session continuity.
---

# Session handoff

Fresh context beats a rotten 12-hour chat. Persist state in the **repo**,
not only in conversation.

## Paths

Prefer one active handoff:

1. `HANDOFF.md` at repo root (default), or
2. `.cursor/handoff/<slug>.md` when several features run in parallel

Template: `skills/session-handoff/references/handoff-template.md`
(SSOT under this rules pack).

## Resume

1. Read the handoff file if it exists.
2. Re-run the listed TOOLCHAIN/CI commands before claiming prior work is green.
3. Do **one** Next action unless the user said autopilot/`sigue`.
4. Do not re-discover the whole codebase; open only paths listed or needed.

## Pause / update

Default compact root `HANDOFF.md` (also seeded by `stop_gate.sh`):

```
TASK
…
FILES
…
STATUS
…
NEXT
…
```

For richer multi-session pauses, use the template (`Goal` / `Done` / `Open` / `Next`) under
`skills/session-handoff/references/handoff-template.md`. Always English labels.

When MCP `user-obsidian` is ready: **also** write/append a Session note under
`wiki/projects/<slug>/Sessions/` with `[[wikilinks]]` to Index/Decisions/Learnings
and refresh `wiki/hot.md` (Skill `obsidian-memory`). Repo handoff + vault — both.

## Rules

- Assessment-only until the user asked for changes (per agent.mdc).
- Never invent residual features; append open items to this handoff.
- Pair with testing for feature execution; debugging if Open is ambiguous.
- Pair with `obsidian-memory` so chat death does not erase the graph.
