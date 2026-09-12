---
name: ponytail
description: >
  Split recovery and module boundaries. Use when writing, editing, or
  splitting any app code. Ladder and roofs live in core.mdc. Not for
  diagnosis (use debugging) or test design (use testing).
---

# Ponytail

Thin roof: `core.mdc` (ladder, size, craft). `stop.sh` checks churn, mass reindent, and shell/JSON syntax (advisory).

## Split

Read → plan → Write new modules → StrReplace original to imports → Grep callers. Never Shell sed/echo>/tee.

`domains/` only if the project uses DDD: [domains-ddd.md](domains-ddd.md). `frontend/` + `backend/` only if the project separates them: [fe-be-layout.md](fe-be-layout.md).

## Floors

Trust, authz, data-loss, a11y, explicit asks. Cyclo: `core.mdc`. Style yields to task and explicit user direction.
