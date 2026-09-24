# Redis / Upstash

Antes de escribir código con Redis, confirma en el `package.json` qué cliente
usa el repo (`@upstash/redis`, `ioredis`, `redis`) y lee la versión instalada.
No mezcles clientes.

## Cliente único

```ts
// platform/redis-client.ts
import { Redis } from '@upstash/redis';

// Upstash usa REST: seguro en serverless/edge y sin pool que agotar.
export const redis = Redis.fromEnv(); // UPSTASH_REDIS_REST_URL / _TOKEN
```

Con `ioredis` en un servidor persistente: una sola instancia a nivel de módulo,
nunca `new Redis()` dentro de un handler.

## Claves por dominio

```ts
// features/modules/module.cache.ts
const CACHE_VERSION = 'v1'; // súbela si cambia la forma del DTO cacheado

export const MODULE_CACHE_TTL_SECONDS = 300;

export const moduleCacheKey = {
  list: (workspaceId: string) => `app:modules:list:${workspaceId}:${CACHE_VERSION}`,
  detail: (moduleId: string) => `app:modules:detail:${moduleId}:${CACHE_VERSION}`,
};
```

## Cache-aside en la query

```ts
// features/modules/queries/list-modules.query.ts
import { redis } from '@/platform/redis-client';
import { selectWorkspaceModules } from '../module.repository';
import { moduleCacheKey, MODULE_CACHE_TTL_SECONDS } from '../module.cache';
import { moduleSummaryList, type ModuleSummary } from '../module.schema';

export async function listWorkspaceModules(workspaceId: string): Promise<ModuleSummary[]> {
  const cacheKey = moduleCacheKey.list(workspaceId);
  const cachedModules = moduleSummaryList.safeParse(await redis.get(cacheKey));
  if (cachedModules.success) return cachedModules.data;

  const workspaceModules = await selectWorkspaceModules(workspaceId);
  await redis.set(cacheKey, workspaceModules, { ex: MODULE_CACHE_TTL_SECONDS });
  return workspaceModules;
}
```

Validar lo que sale del cache con el schema evita que un DTO viejo rompa la UI
después de un deploy.

## Invalidación

- En el command, **después** de escribir en SQL: `redis.del(...claves exactas)`.
- Varias claves: `redis.del(keyA, keyB)` o un `pipeline()`.
- No uses `KEYS app:modules:*` en producción (bloquea Redis). Si necesitas
  invalidar un grupo, sube la versión o guarda las claves del grupo en un set.
- Si además usas el cache del framework (Next `unstable_cache`/`'use cache'` con
  tags), invalida ambos en el mismo command: `redis.del(...)` + `revalidateTag(...)`.

## Otros roles

- **Rate limit**: `@upstash/ratelimit` en el borde del command o middleware,
  devolviendo `fail('RATE_LIMITED', ...)`, no un 500.
- **Lock**: `SET key token NX PX ms` y liberar solo si el token coincide.
- **Tiempo real**: Upstash REST no mantiene suscripciones pub/sub abiertas en
  serverless. Para que otras pestañas/usuarios vean cambios, usa refetch por
  intervalo o foco (TanStack Query), SSE desde un servidor persistente, o un
  servicio realtime. Nunca `location.reload()` en un intervalo.
- **Fuente de verdad** (contadores, sesiones): decláralo en el archivo `.cache.ts`
  de la feature con un comentario de por qué, y ahí sí puede ir sin TTL.
