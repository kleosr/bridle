# SQL y repositorios

## Reglas

1. **Parametrizado siempre.** Tagged template (`sql\`... ${valor}\``) de
   postgres.js / Neon / Vercel Postgres / Drizzle, o placeholders `$1`. Nunca
   concatenar o interpolar en un string plano.
2. **Columnas explícitas.** `SELECT id, slug, title` — nunca `SELECT *`.
3. **Un repositorio por agregado**: `features/<dominio>/<dominio>.repository.ts`.
   Es el único archivo que conoce las tablas de ese dominio. Commands y queries lo
   llaman; componentes y actions nunca.
4. **Mapeo en el borde**: la DB usa `snake_case`, TS usa `camelCase`. El
   repositorio convierte fila → DTO; nada fuera de él ve nombres de columnas.
5. **Transacción** cuando un command hace más de una escritura o lee-y-escribe
   algo que otro request podría cambiar.
6. **Migraciones** forward-only, con nombre descriptivo
   (`20260924_add_modules_position.sql`), en la carpeta que el repo ya usa. Nada
   de `CREATE TABLE` dentro del código de la app.
7. **Restricciones en la DB**, no solo en la app: `UNIQUE (workspace_id, slug)`,
   `NOT NULL`, FKs. La validación zod es para mensajes; la DB es la garantía.
8. **Índices** para las consultas que existen, medidos con `EXPLAIN`.
9. Si usas ORM (Prisma/Drizzle), mismas reglas: `select` explícito, el cliente
   solo en el repositorio, transacciones con la API del ORM.

## Plantilla (postgres.js / Neon)

```ts
// features/modules/module.repository.ts
import { sql } from '@/platform/db-client';
import type { ModuleSummary } from './module.schema';

type ModuleRow = { id: string; slug: string; title: string; position: number };

const toModuleSummary = (moduleRow: ModuleRow): ModuleSummary => ({
  id: moduleRow.id,
  slug: moduleRow.slug,
  title: moduleRow.title,
  position: moduleRow.position,
});

export async function selectWorkspaceModules(workspaceId: string): Promise<ModuleSummary[]> {
  const moduleRows = await sql<ModuleRow[]>`
    SELECT id, slug, title, position
    FROM modules
    WHERE workspace_id = ${workspaceId} AND archived_at IS NULL
    ORDER BY position`;
  return moduleRows.map(toModuleSummary);
}

export async function updateModuleTitle(moduleId: string, title: string): Promise<ModuleSummary | null> {
  const [updatedRow] = await sql<ModuleRow[]>`
    UPDATE modules SET title = ${title}, updated_at = now()
    WHERE id = ${moduleId}
    RETURNING id, slug, title, position`;
  return updatedRow ? toModuleSummary(updatedRow) : null;
}
```

## Command completo con transacción e invalidación

```ts
// features/modules/commands/rename-module.command.ts
import { fail, succeed, type Result } from '@/platform/result';
import { redis } from '@/platform/redis-client';
import { renameModuleInput, type ModuleSummary } from '../module.schema';
import { updateModuleTitle } from '../module.repository';
import { moduleCacheKey } from '../module.cache';
import { canEditWorkspace, type Actor } from '@/features/session/actor';

export async function renameModule(actor: Actor, input: unknown): Promise<Result<ModuleSummary>> {
  const parsedInput = renameModuleInput.safeParse(input);
  if (!parsedInput.success) {
    return fail('VALIDATION_FAILED', 'Revisa el título.', parsedInput.error.flatten().fieldErrors);
  }
  const { workspaceId, moduleId, title } = parsedInput.data;
  if (!canEditWorkspace(actor, workspaceId)) return fail('FORBIDDEN', 'No puedes editar este workspace.');

  const renamedModule = await updateModuleTitle(moduleId, title);
  if (!renamedModule) return fail('NOT_FOUND', 'El módulo ya no existe.');

  await redis.del(moduleCacheKey.list(workspaceId)); // después del commit
  return succeed(renamedModule);
}
```
