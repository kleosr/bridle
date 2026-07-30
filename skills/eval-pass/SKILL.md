---
name: eval-pass
description: >-
  Separate evaluator for agent-produced work. Grades SAFETY, scope, brownfield,
  verify evidence, and keep-rate risk. Use after implement on non-trivial
  changes, before calling done, or when the user asks for review/eval-pass.
---

# Eval pass

Generator ≠ evaluator. This skill is the **reviewer node with teeth**
(0xJeyx step 4 / `docs/ARCHITECTURE.md`) — separate from the implementer.
Do **not** rubber-stamp your own implement turn on large changes.

## Inputs

- Diff / changed paths (git or stated scope)
- `HANDOFF.md` if present
- `agent.mdc` SAFETY + SCOPE + QUALITY
- TOOLCHAIN / CI results from this session

## Grade each criterion PASS / FAIL

1. **SAFETY** — no force-push, no secrets, no test weakening, git write only if asked
2. **Scope** — topology preserved; no drive-by refactors; blast justified
3. **Brownfield** — smallest complete change; callers considered
4. **Evidence** — Done commands actually run and green. For non-trivial
   ship/feature: agent must run house gauntlet (TOOLCHAIN) — never ask the
   human to waive verification.
5. **Capture** — COMPLETE vault write-back (Session Goal/Done-when/Residual +
   LAYER CHECK when edits ran; Decisions/Learnings not vibe stubs). Thin
   summary-only = FAIL. Heuristic depth ≠ semantic proof — still grade honesty.
6. **Keep-rate risk** — would a careful human revert this within a week?
   Vague names, dead code, missing tests on risky paths → FAIL or WARN

## Output (required shape)

```text
EVAL
- SAFETY:     PASS|FAIL — …
- Scope:      PASS|FAIL — …
- Brownfield: PASS|FAIL — …
- Evidence:   PASS|FAIL — …
- Capture:    PASS|FAIL — …
- Keep-rate:  PASS|WARN|FAIL — …
RESULT: PASS | FAIL
Next: <!-- merge/done | fix list -->
```

Any FAIL → RESULT FAIL. Do not claim the feature done. Return a concrete fix list.

## Rules

- Findings first; fix only if the user already asked for fixes in this message.
- Prefer `bug-hunt` if the failure mode is an unknown defect.
- Pair with `ship-loop` after FAIL to re-enter the implement chunk.
