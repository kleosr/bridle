# Domain code — `domains/` trees only

Apply only under a `domains/` folder (e.g. `backend/src/domains/**`).
Full DDD / event-modeling is required here — the core "no unrequested abstractions" rule does not exempt you.
Never import this ceremony into scripts, CLIs, or one-off tools.

## Naming (strict)

- Commands: imperative `<Verb><Subject>` (`SubmitOrder`)
- Events: past-tense `<Subject><Verb>` (`OrderSubmitted`), never imperative
- Aggregates: PascalCase entities (`Order`)
- Read models: `<Purpose>View` / `<Purpose>Projection`
- Policies: `<Workflow>Policy`
- Reject vague names (`DoStuff`, `HandleEvent`)

## Structure

- One bounded context per folder:
  `domains/<context>/{commands,events,aggregates,projections,policies,lib}` — never mixed.
- Outside modules talk to an aggregate through commands and events, never internal state.
- Law of Demeter: no deep property chains across aggregates.
- Explicit types on every public API; no `any`.
- Value objects for concepts with invariants (`Money`, `EmailAddress`, `OrderId`) instead of bare primitives.

## Tests (overrides core single-check)

- Full suite for domain code: command → correct event or domain error; projection → correct state from an event sequence.
- >80% coverage on new domain code.
