# Ejemplo trabajado: "crea un sidebar con módulos, con Upstash y Redis"

Next.js App Router + Postgres + Upstash. Adapta los nombres a la convención del
repo si ya existe (skill `code-architecture`).

## Archivos

```
src/app/(workspace)/[workspaceSlug]/layout.tsx         # monta el sidebar una vez
src/app/(workspace)/[workspaceSlug]/[moduleSlug]/page.tsx
src/app/(workspace)/[workspaceSlug]/[moduleSlug]/loading.tsx
src/features/modules/module.schema.ts
src/features/modules/module.repository.ts
src/features/modules/module.cache.ts
src/features/modules/module.routes.ts
src/features/modules/queries/list-modules.query.ts
src/features/modules/commands/create-module.command.ts
src/features/modules/commands/create-module.action.ts
src/features/modules/components/workspace-sidebar.tsx
src/features/modules/components/module-create-form.tsx
```

## Layout: el shell no se desmonta

```tsx
// app/(workspace)/[workspaceSlug]/layout.tsx
import { listWorkspaceModules } from '@/features/modules/queries/list-modules.query';
import { WorkspaceSidebar } from '@/features/modules/components/workspace-sidebar';
import { resolveWorkspace } from '@/features/workspaces/queries/resolve-workspace.query';

export default async function WorkspaceLayout({ children, params }: LayoutProps<'/[workspaceSlug]'>) {
  const { workspaceSlug } = await params;
  const workspace = await resolveWorkspace(workspaceSlug);
  const workspaceModules = await listWorkspaceModules(workspace.id);
  return (
    <div className="workspace-shell">
      <WorkspaceSidebar workspaceSlug={workspaceSlug} modules={workspaceModules} />
      <main>{children}</main>
    </div>
  );
}
```

(Verifica la firma de `params` y los tipos de props en la versión de Next
instalada; en versiones recientes `params` es una Promise.)

## Command + action: escribir, invalidar Redis y el cache de Next

```ts
// features/modules/commands/create-module.action.ts
'use server';
import { revalidatePath } from 'next/cache';
import { createModule } from './create-module.command';
import { requireActor } from '@/features/session/queries/get-current-actor.query';

export async function createModuleAction(workspaceSlug: string, input: unknown) {
  const actor = await requireActor();
  const creationOutcome = await createModule(actor, input); // SQL + redis.del dentro
  if (creationOutcome.ok) revalidatePath(`/${workspaceSlug}`, 'layout'); // re-render del sidebar
  return creationOutcome;
}
```

Dos capas invalidadas: Redis dentro del command (verdad del servidor) y el cache
del framework en la action (lo que el RSC ya renderizó).

## Formulario: sin reload, con error por campo

```tsx
// features/modules/components/module-create-form.tsx
'use client';
import { useActionState } from 'react';
import { createModuleAction } from '../commands/create-module.action';

type CreateFormState = Awaited<ReturnType<typeof createModuleAction>> | null;

export function ModuleCreateForm({ workspaceSlug }: { workspaceSlug: string }) {
  const [creationOutcome, submitModuleCreation, isCreating] = useActionState(
    async (_previous: CreateFormState, formData: FormData) =>
      createModuleAction(workspaceSlug, { title: formData.get('title') }),
    null,
  );
  const titleErrors = creationOutcome && !creationOutcome.ok ? creationOutcome.error.fieldErrors?.title : undefined;
  return (
    <form action={submitModuleCreation}>
      <input name="title" aria-invalid={Boolean(titleErrors)} disabled={isCreating} />
      {titleErrors?.map((titleError) => <p key={titleError} role="alert">{titleError}</p>)}
      <button type="submit" disabled={isCreating}>Crear módulo</button>
    </form>
  );
}
```

Al enviar: el command escribe, invalida, `revalidatePath` refresca el layout y el
nuevo módulo aparece en el sidebar en la misma respuesta. Cero recargas.

## Variante con TanStack Query (SPA / Vite)

```ts
// features/modules/components/use-create-module.ts
export const moduleQueryKey = {
  list: (workspaceId: string) => ['modules', 'list', workspaceId] as const,
};

export function useCreateModule(workspaceId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (title: string) => apiClient.createModule(workspaceId, { title }), // devuelve Result
    onSuccess: (creationOutcome) => {
      if (!creationOutcome.ok) return;
      queryClient.setQueryData<ModuleSummary[]>(moduleQueryKey.list(workspaceId), (currentModules = []) =>
        [...currentModules, creationOutcome.data]);
      queryClient.invalidateQueries({ queryKey: moduleQueryKey.list(workspaceId) });
    },
  });
}
```

## Checklist de este flujo

- [ ] Sidebar en layout, item activo desde la URL.
- [ ] Módulos desde query cacheada (Redis con TTL), no hardcodeados.
- [ ] Command invalida Redis; action/mutación invalida el cache de UI.
- [ ] Crear un módulo lo muestra en el sidebar sin F5 y sin petición "Doc" nueva.
- [ ] `quality-gate.mjs` en 0 errores.
