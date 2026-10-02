---
name: slop-guard
description: >-
  Write-time patterns that reject low-evidence TypeScript and JavaScript: fake
  types (unknown contracts, chained or widen-then-assert casts), wasteful array
  and reducer passes, module mocking, and reflection. Use when writing or
  editing .ts, .tsx, .js, .jsx, .mjs, or .cjs code. Adds no dependency or lint
  config; applies to new and changed lines only.
---

# Slop guard

Low-evidence code claims a type or a behavior that nothing proves. Write the
proof into the code, at the boundary where the data enters. Apply this to the
lines you write or change. Do not migrate old code unless the ask says so.

## Types carry evidence

| Do | Do not |
|---|---|
| Parse input once at the boundary (schema, type guard, or explicit checks), then pass the narrow type. | Accept `unknown` (or a union with it) as a function parameter. The `cause` of an error and the subject of a type predicate are the exceptions. |
| Return the real type. | Declare a return of `unknown`, `Promise<unknown>`, or an alias that resolves to `unknown`. |
| Give a dictionary a real value type: `Record<UserId, User>`, `Map<string, Order>`. | Use `Record<string, unknown>`, `any`, `object`, or `{}` as a value contract. A generic constraint like `T extends Record<string, unknown>` is allowed. |
| Keep a known value at its known type. | Pass a known value into an `unknown`, `object`, or open-dictionary slot, then assert it back. |
| Cast only when a check in the same flow proves the type. Put that proof in code, not in a comment. | Chain assertions (`x as unknown as T`, `<T><unknown>x`). `as const` is allowed. |
| Narrow with a parser or a type predicate at the boundary. | Scatter ad hoc `typeof x === "..."` checks through business code. `typeof x === "undefined"` probes are allowed. |
| Call functions and read properties through their types. | Use `Reflect.apply` or `Reflect.get` to skip the type system. |
| Name the domain thing: `User`, `OrderLine`. | Put `Shape` in a local symbol name (`UserShape`). A library member such as `schema.shape` is allowed. |

## Data passes stay linear

- Do one pass, not `.filter(...).map(...)`. Use `flatMap`, a loop, or lazy `.values().filter(...).map(...).toArray()` when the runtime supports iterator helpers. Keep callback order, indexes, and `thisArg` semantics the same.
- In `reduce`, mutate a fresh local accumulator. Do not copy it on every step with spread, `Object.assign({}, acc, ...)`, `Array.from(acc)`, `concat`, or `slice`.
- To omit an optional field, build the object with an `if`. Do not use `...(cond ? { a } : {})`: omitting a key and setting it to `undefined` are different.

## Tests use real seams

Do not call `vi.mock`, `jest.mock`, `doMock`, or `unstable_mockModule`. Pass the dependency in (parameter, constructor, or layer) and give the test a real or in-memory implementation.

## Effect

Apply this section only when the owning package manifest declares `effect`.

- Match tagged values with `Match`, `Predicate.isTagged`, or tagged-enum matching. Do not compare or switch on `_tag` by hand, including inside `Effect.catch` handlers.
- Build tagged values with Schema, a tagged class or error, or `Data.taggedEnum`. Do not write `{ _tag: "..." }` literals.
- Runtime callers import the owning Layer and yield the service. Do not import `make<Service>` constructors from project modules outside tests.
- Replace chained literal ternaries over one value with `Match`.

## Source

Adapted from the rule set of [dmmulroy/anti-slop](https://github.com/dmmulroy/anti-slop) (MIT) at `c44ef22`. To enforce these rules with Oxlint in a repo, install that project's `install-anti-slop` skill. Adding the dependency needs approval.
