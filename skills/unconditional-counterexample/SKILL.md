---
name: unconditional-counterexample
description: >
  Runs a fixed 4-phase hunt that delivers one complete unconditional
  counterexample without the user re-prompting between phases. Self-target
  pause against this pack’s law. Escalate to /breakthrough-deepen after a
  chain tip exists. Use on /unconditional-counterexample, counterexample
  mantra, "fully works", "breakthrough", "partial results", or a structured
  counterexample ask against a claim/conjecture/rules/product.
---

# Unconditional Counterexample

First-hunt skill. Delivers **one** finished \(P^*\).

After a chain tip exists, escalate to `/breakthrough-deepen` (do not re-run
Phases 1→4 as a fake deepen).

## When to run

- User invokes `/unconditional-counterexample`
- Pastes a counterexample / breakthrough mantra for a first hunt
- Says “fully works”, “breakthrough”, “partial results” (first \(P^*\))
- Wants a structured counterexample to a claim / conjecture / rules / product
- Cold start: no prior `## Breakthrough chain` / `.cursor/breakthrough-chain.md`

## Self-target rule

If `{problem}` targets this pack’s own law (Master Mind / USER-RULES / kleosr /
always-on companions / Bash hooks):

1. Do **not** auto-advance Phases 1→4.
2. Emit Phase-1 sketch only (restate \(C\), map structure, candidate seam).
3. ASK ONCE: confirm hunt against this session’s own loaded law.
4. On explicit confirm → resume Phases 2→4 in the same turn-loop.
5. On no confirm → stop. Never auto-finish a \(P^*\) against the loaded constitution.

Self-target outranks the auto-pipeline below.

Foreign products/claims: keep the auto-pipeline unchanged.

## Auto-pipeline (single reply, no user re-prompt)

On invoke, fill `{problem}` from the user message.

Then run **Phases 1→2→3→4 in order in this same turn-loop** (unless Self-target
paused). Do not stop after Phase 1 or 2 for the user to paste the next block.
Advance until Phase 4’s done-when is met (or a hard blocker: missing target
text / no readable sources).

Track progress mentally:

```
- [ ] Phase 1 — structured breakthrough
- [ ] Phase 2 — complete unconditional
- [ ] Phase 3 — strategy from structure
- [ ] Phase 4 — finish (no partials)
```

---

## Phase 1 — breakthrough (verbatim shape)

Construct a counterexample to general ({problem}). You should do a breakthrough and find a structured counterexample.

(Archetype fill from the user’s screenshot pattern: `non-planar case of Dinitz Garg Goemans conjecture` — replace with whatever `{problem}` they named.)

**Agent does:** Restate \(C\). Map structure. Produce a first structured candidate \(P\) (or prove why none yet). Do **not** end the run here — **except** Self-target pause (Phase-1 + ASK only).

---

## Phase 2 — continue (verbatim)

please continue research and find a complete unconditional counterexample

**Agent does:** Deepen evidence. Kill weak/partial candidates. Push toward complete + unconditional. Continue immediately into Phase 3 if still incomplete.

---

## Phase 3 — strategy (verbatim)

Continue the search. Have a clear strategy obtained from deeper understanding of the problem structure.

**Agent does:** State the structural strategy in 1–3 sentences, then use it to search again (writers/readers, dropped fields, dual surfaces, conjunction/precedence holes, etc.). Do not stop at “here is a strategy.”

---

## Phase 4 — finish (verbatim)

it's enough of partial results. let's finish with a complete unconditional counterexample

**Agent does:** Deliver **one** finished \(P^*\). No ranked maybe-list as the answer.

---

## Done-when (Phase 4 only)

| Property | Meaning |
|----------|---------|
| **Complete** | Claim \(C\), instance \(P^*\), failure mode, file:line or clause evidence, why \(\neg C\) |
| **Unconditional** | Fails by construction — no race, flake, network, token expiry, or “sometimes” |

Sibling gaps only **after** \(P^*\). They do not replace \(P^*\).

## Hunt checklist

- Split brain (two writers / reader ignores a write)
- Dropped field (producer has \(X\); consumer hardcodes default)
- Dead claimed path (exists, never used on advertised flow)
- Missing gate (upstream checks; this surface skips)
- Conjunction / precedence / ACT-vs-gated label clashes (rules targets)

## Output (emit once at Phase 4)

```markdown
## Verdict
[one line]

## Strategy
[1–3 sentences from Phase 3]

## Claim (C)
…

## Instance (P*)
1. …
2. …
3. …

## Failure (by construction)
- Evidence: …
- What always happens
- Why this falsifies C

## Sibling gaps (optional)
| Gap | Why weaker |
```

## Adapter notes (Cursor only)

- If workspace exists → write/update `.cursor/breakthrough-chain.md` with the new tip after Phase 4.
- Pure chat / no workspace → chain lives only in the reply.
- To go deeper than this tip → `/breakthrough-deepen` (max 2 upgrades; A2-fail-closed allowed).

## Anti-patterns

- Stopping after Phase 1–3 for the user to paste the next prompt (except Self-target rule)
- Ending on partial concerns with no \(P^*\) (except Self-target stop without confirm)
- Flaky live-only “might fail”
- Fixing during the hunt unless asked
- Auto-finishing a \(P^*\) against this pack’s law without Self-target confirm
- Re-running Phases 1→4 as a fake deepen when a chain tip already exists (use `/breakthrough-deepen`)

## After delivery

Fix plan only if the user asks. Kill \(P^*\) only; no sibling-gap expansion unless asked.
