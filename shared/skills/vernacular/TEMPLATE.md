# Vernacular contract (copy into the app repo)

Put this at `.cursor/rules/vernacular.mdc` (`alwaysApply: true`) or `VERNACULAR.md`.

Fill fields from **existing** code — do not invent a dialect.

```md
---
description: Private vernacular for this repo — naming, files, visibility.
alwaysApply: true
---

# Vernacular

Machine fields (hooks parse key: value):

```
file_name_pattern: domain.kind.ext
allowed_kinds: type, service, usecase, adapter, controller, rule, test
allowed_path_prefixes: src/, tests/, app/
forbidden_class_suffixes: 
class_pattern: PascalCaseWithKindSuffix
function_pattern: verbObject
boolean_prefixes: is, has, can, should
constant_pattern: SCREAMING_SNAKE_CASE
no_prose_comments: true
machine_directives_only: ts-expect-error, eslint-disable-next-line, shebang
```

## Topology
- Shape: TBD
- New files allowed under: set `allowed_path_prefixes` (gated) — e.g. `src/, tests/`
- Never create: TBD

## File names
- Pattern: TBD (e.g. `user.create.usecase.ts`)
- Test files: TBD
- One export style: TBD

## Types / classes
- Prefer: TBD
- Class names: TBD (e.g. UserCreateUseCase)
- Interfaces/types: TBD
- Visibility: TBD

## Functions
- Names: TBD (e.g. createUser)
- Async suffix: TBD
- Error/result style: TBD

## Imports
- Order: TBD
- Alias: TBD

## Forbidden
- Prose comments
- New workspace/monorepo tooling
- Foreign Clean Architecture folders
```

Example file names (when using domain.kind.ext):

```
user.create.usecase.ts
user.create.usecase.test.ts
billing.invoice.service.ts
auth.session.adapter.ts
```

Example class names:

```
UserCreateUseCase
BillingInvoiceService
AuthSessionAdapter
```

Example function names:

```
createUser
validateInvoice
refreshSession
```
