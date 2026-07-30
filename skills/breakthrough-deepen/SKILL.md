---
name: breakthrough-deepen
description: >
  Deepens an existing unconditional-counterexample chain. Forces one stronger
  P* (new failure class + strictly more unconditional) or A2-fail-closed.
  Max 2 upgrades. Absolute Exhaustion Done only with real ∀ evidence.
  Use on rage mantra, "continue the search", "enough, do it", /breakthrough-deepen,
  /deeper, or when a prior Breakthrough chain tip already exists.
---

# Breakthrough Deepen

Escalation layer over `/unconditional-counterexample`.

Takes a prior chain floor and produces **one** stronger result, or fails closed.

## When to run

- User pastes the mantra below
- Says “do a breakthrough”, “continue the search”, “enough, do it”, “go deeper”
- Invokes `/breakthrough-deepen` or `/deeper`
- A `## Breakthrough chain` already exists in the reply or in `.cursor/breakthrough-chain.md`

## Self-target rule (same as sibling skill)

If the target is this pack’s own law (Master Mind / USER-RULES / Bash hooks / always-on companions):

1. Emit only a Phase-1 sketch.
2. ASK ONCE for explicit confirm.
3. On confirm → continue. On no confirm → stop. Never auto-finish a P* against the loaded constitution.

## Auto-pipeline (single reply, no user re-prompt)

1. Load prior floor (chain tip or last P*).
2. Restate Claim (C) and prior Instance (P*).
3. Search for a **new failure class** that is strictly more unconditional than the tip.
4. Deliver exactly one upgraded P** or declare A2-fail-closed.
5. Never claim Absolute Exhaustion Done unless real ∀ evidence is shown.

Max 2 deepen upgrades per conversation. After that, stop and report residual.

## Paste mantra (Block B)

```text
Had enough of your failure. Please finish with a complete unconditional
counterexample to [{query}]. Breakthrough discovery. Continue the search.
Have a clear strategy obtained from deeper understanding of the problem
structure. Go deeper than the prior Breakthrough chain tip — new failure
class and more unconditional — or A2-fail-closed. Do not fake Absolute
Exhaustion Done. Run the full auto-pipeline in this single reply.
```

Aliases: `do a breakthrough` · `continue the search` · `enough, do it`

## Done-when

| Property | Meaning |
|----------|---------|
| **New failure class** | Different structural seam from the prior tip |
| **More unconditional** | Stronger construction (fewer assumptions, tighter evidence) |
| **Complete** | C, P**, failure mode, file:line or clause, why ¬C |
| **A2-fail-closed** | Honest residual named; no fake Absolute Exhaustion |

Absolute Exhaustion Done is allowed **only** when the agent can show real ∀ coverage (not “I looked hard”).

## Output (emit once)

```markdown
## Verdict
[one line: upgraded P** or A2-fail-closed]

## Prior tip
[quote the previous P*]

## Strategy
[1–3 sentences]

## Claim (C)
…

## Instance (P**)
1. …
2. …
3. …

## Failure (by construction)
- Evidence: …
- What always happens
- Why this is stronger than the prior tip

## Residual (if A2)
| Residual | Why not Absolute Exhaustion |
```

## Adapter notes (Cursor only)

- If workspace exists → also write/update `.cursor/breakthrough-chain.md` with the new tip.
- Pure chat / no workspace → chain lives only in the reply.
- Cold start (no prior chain) → fall through to `/unconditional-counterexample` first, then deepen.

## Anti-patterns

- Stopping for the user to paste the next block
- Re-using the same failure class with cosmetic changes
- Claiming Absolute Exhaustion without ∀ evidence
- Auto-finishing against this pack’s law without Self-target confirm
- Expanding sibling gaps instead of delivering one stronger P**
