---
name: cqrs-data-flow
description: >-
  Capa de datos consistente con CQRS: commands que escriben, queries que leen,
  un solo contrato de respuesta, SQL parametrizado por repositorio y Redis/Upstash
  como cache con TTL e invalidación explícita. Úsala SIEMPRE que el código lea o
  escriba datos: SQL, Postgres, Prisma, Drizzle, Supabase, Redis, Upstash, server
  actions, route handlers, API endpoints, fetch, formularios, mutaciones, caching,
  rate limit o colas, aunque el usuario no diga "CQRS". También cuando las
  respuestas o requests son inconsistentes entre pantallas.
---

# CQRS data flow

La inconsistencia entre requests viene de que cada pantalla inventa su forma de
pedir, escribir y cachear. Esta skill fija **un camino de escritura, un camino de
lectura y un contrato**, para que cada feature se vea igual por dentro.

## El flujo (memorízalo)

```
UI ──(intención)──▶ Command ──▶ validar (zod) ──▶ autorizar ──▶ Repository (SQL, transacción)
                        │                                               │
                        └──▶ invalidar cache (tags / claves Redis) ◀── commit OK
                        └──▶ Result<Dto, DomainError>  ──▶ UI actualiza sin recargar

UI ──(lectura)──▶ Query ──▶ cache Redis (cache-aside, TTL) ──miss──▶ Repository (SELECT columnas)
                                                                   ──▶ DTO tipado
```

## Commands (escriben)

- Archivo `features/<dominio>/commands/<verbo>-<objeto>.command.ts`, una función
  exportada con nombre de intención: `renameModule`, no `updateModule` genérico.
- Orden fijo dentro del command: **parsear input con zod → autorizar al actor →
  ejecutar en repositorio (transacción si hay más de una escritura) → invalidar →
  devolver Result**. No cambies el orden; invalidar antes del commit sirve datos
  viejos.
- Devuelve `Result<T, DomainError>` de `platform/result.ts`. No lances errores de
  negocio hacia la UI; los errores de infraestructura sí pueden lanzarse y se
  registran.
- Devuelve lo mínimo que la UI necesita para actualizarse (el DTO afectado o su
  id), no "toda la página".
- Idempotencia: si el command puede repetirse por doble click o reintento, acepta
  `idempotencyKey` o usa una restricción única en SQL.
- Un command no llama a otro command. Si dos cambios van juntos, es un command
  más grande con una transacción.

## Queries (leen)

- Archivo `features/<dominio>/queries/<list|get>-<objeto>.query.ts`.
- Nunca escriben, nunca invalidan, nunca tienen efectos secundarios (salvo llenar
  su propio cache).
- Devuelven DTOs definidos en `<dominio>.schema.ts`, no filas crudas de la DB.
- Paginación por cursor (keyset) para listas que crecen; `OFFSET` solo en tablas
  pequeñas y acotadas.

## Contrato de respuesta (uno solo en todo el repo)

```ts
type Result<T> =
  | { ok: true; data: T }
  | { ok: false; error: { code: DomainErrorCode; message: string; fieldErrors?: Record<string, string[]> } };
```

Toda server action, route handler y cliente HTTP usa esta forma. Detalles,
códigos de error y el helper para route handlers en
`references/request-contract.md`.

**Un solo transporte por tipo de consumidor**: server actions (o el equivalente
del framework) para la UI propia; route handlers solo para webhooks, clientes
externos o móviles. No mezcles `fetch('/api/...')` desde la UI propia con server
actions para el mismo dominio.

## SQL

Reglas completas y plantillas en `references/sql-repository.md`. Lo esencial:
parametrizado siempre, columnas explícitas, un repositorio por agregado (único
lugar con SQL de ese dominio), migraciones forward-only con nombre, transacción
para escrituras múltiples, `snake_case` en DB y `camelCase` en TS con el mapeo
en el repositorio. Si el repo usa Postgres o Supabase, aplica además las companions `postgres` y
`supabase` del harness, solo cuando el `package.json` dueño lo confirma.

## Redis / Upstash

Plantillas en `references/redis-upstash.md`. Lo esencial:

- Declara el rol de Redis en la feature: **cache de lectura**, **rate limit**,
  **lock**, o **fuente de verdad**. Por defecto es cache y la verdad está en SQL.
- Claves construidas solo desde `<dominio>.cache.ts`:
  `app:<dominio>:<entidad>:<id>:v<n>`. Nunca strings armados a mano en el command.
- Todo `set` de cache lleva TTL (`{ ex: segundos }`).
- La invalidación ocurre en el command, después del commit, borrando las claves
  exactas o subiendo la versión de la clave. Nunca "esperar a que expire" como
  estrategia para cambios del propio usuario.
- Un cliente Redis compartido en `platform/redis-client.ts` (`Redis.fromEnv()` en
  Upstash); no instancies clientes dentro de componentes o por request.

## Verificación

1. Test del command: input inválido → `ok:false` con `fieldErrors`; actor sin
   permiso → `ok:false` con `FORBIDDEN`; caso feliz → fila escrita y clave de
   cache invalidada.
2. Test de la query: cache miss llena el cache con TTL; cache hit no toca SQL.
3. `quality-gate.mjs` de `code-architecture` sin errores.
4. La UI refleja el cambio sin recarga → ver `live-ui-sync`.
