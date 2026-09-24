# Contrato de requests

## platform/result.ts

```ts
export type DomainErrorCode =
  | 'VALIDATION_FAILED'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'RATE_LIMITED'
  | 'UNEXPECTED';

export type DomainError = {
  code: DomainErrorCode;
  message: string;
  fieldErrors?: Record<string, string[]>;
};

export type Result<T> = { ok: true; data: T } | { ok: false; error: DomainError };

export const succeed = <T>(data: T): Result<T> => ({ ok: true, data });
export const fail = (code: DomainErrorCode, message: string, fieldErrors?: Record<string, string[]>): Result<never> =>
  ({ ok: false, error: { code, message, fieldErrors } });
```

## Mapeo a HTTP (solo route handlers)

| code | status |
| --- | --- |
| VALIDATION_FAILED | 422 |
| UNAUTHENTICATED | 401 |
| FORBIDDEN | 403 |
| NOT_FOUND | 404 |
| CONFLICT | 409 |
| RATE_LIMITED | 429 |
| UNEXPECTED | 500 |

```ts
// platform/http-response.ts
import type { Result, DomainErrorCode } from './result';

const STATUS_BY_CODE: Record<DomainErrorCode, number> = {
  VALIDATION_FAILED: 422, UNAUTHENTICATED: 401, FORBIDDEN: 403,
  NOT_FOUND: 404, CONFLICT: 409, RATE_LIMITED: 429, UNEXPECTED: 500,
};

export function toHttpResponse<T>(outcome: Result<T>, successStatus = 200): Response {
  const status = outcome.ok ? successStatus : STATUS_BY_CODE[outcome.error.code];
  return Response.json(outcome, { status });
}
```

## Server action (Next.js) que envuelve un command

```ts
// features/modules/commands/rename-module.action.ts
'use server';
import { renameModule } from './rename-module.command';
import { requireActor } from '@/features/session/queries/get-current-actor.query';

export async function renameModuleAction(input: unknown) {
  const actor = await requireActor();
  return renameModule(actor, input); // ya devuelve Result
}
```

La action es un adaptador delgado: sin lógica de negocio, sin SQL.

## Parseo de input

```ts
const parsedInput = renameModuleInput.safeParse(input);
if (!parsedInput.success) {
  return fail('VALIDATION_FAILED', 'Revisa los campos.', parsedInput.error.flatten().fieldErrors);
}
```

## Cliente (cuando sí hay fetch a un route handler)

Un solo helper en `platform/api-client.ts` que siempre devuelve `Result<T>`,
nunca lanza por status 4xx, y valida la respuesta con el schema del DTO. Ningún
componente llama `fetch` directo.
