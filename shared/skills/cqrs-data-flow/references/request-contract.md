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

## API pública (clientes externos, móviles, terceros)

Aplica solo a route handlers que consume alguien fuera de este repo. La UI
propia sigue con server actions.

- **Versionado en la ruta** (`/v1/...`). Dentro de una versión solo cambios
  compatibles: agregar campos opcionales o endpoints. Quitar o renombrar un
  campo, cambiar un tipo o un código de error → nueva versión y deprecación con fecha.
- **Semántica HTTP**: `GET` sin efectos, `PUT`/`DELETE` idempotentes, `POST`
  crea o ejecuta. `201` + `Location` al crear; `204` sin cuerpo.
- **`Idempotency-Key`** en todo `POST` con efectos (pagos, envíos, creación):
  guarda clave + hash del body + respuesta con TTL; misma clave → misma
  respuesta; misma clave con otro body → `409`.
- **Paginación por cursor**: `?limit=&cursor=`, respuesta con `nextCursor`
  (o `null`). `limit` con tope en servidor.
- **Rate limit**: `429` + `Retry-After` y headers `RateLimit-*` (ver
  `system-design/references/realtime-and-rate-limits.md`).
- **Errores**: el mismo `Result` de arriba; `code` estable y documentado, el
  `message` puede cambiar. Nunca stack traces ni SQL en la respuesta.
- **Contrato publicado**: si el repo tiene OpenAPI o schema compartido, el
  cambio lo actualiza en el mismo PR.
