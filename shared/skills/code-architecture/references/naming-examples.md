# Antes / después

## Componente

Antes (genérico, se podría pegar en cualquier app):

```tsx
// components/Sidebar.tsx
export default function Sidebar({ data }: any) {
  const [isLoading, setIsLoading] = useState(false);
  const handleClick = async (item: any) => {
    setIsLoading(true);
    await fetch('/api/data', { method: 'POST', body: JSON.stringify(item) });
    window.location.reload();
  };
  return <div>{data.map((item: any) => <div onClick={() => handleClick(item)}>{item.name}</div>)}</div>;
}
```

Después:

```tsx
// features/modules/components/workspace-sidebar.tsx
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import type { ModuleSummary } from '../module.schema';
import { workspaceModuleHref } from '../module.routes';

type WorkspaceSidebarProps = { modules: ModuleSummary[] };

export function WorkspaceSidebar({ modules }: WorkspaceSidebarProps) {
  const pathname = usePathname();
  return (
    <nav aria-label="Módulos del workspace">
      {modules.map((module) => {
        const href = workspaceModuleHref(module.slug);
        return (
          <Link key={module.id} href={href} aria-current={pathname === href ? 'page' : undefined}>
            {module.title}
          </Link>
        );
      })}
    </nav>
  );
}
```

Qué cambió: nombre con dominio, props tipadas desde el schema, `Link` en vez de
div clicable, estado activo derivado de la URL, sin fetch ni reload dentro de un
componente de navegación. La mutación vive en un command (ver `cqrs-data-flow`).

## Funciones

| Antes | Después |
| --- | --- |
| `getData()` | `listWorkspaceModules(workspaceId)` |
| `process(input)` | `normalizeModuleSlug(rawTitle)` |
| `update(id, data)` | `renameModule({ moduleId, title })` |
| `check(user)` | `assertCanEditWorkspace(actor, workspaceId)` |

## Variables

| Antes | Después |
| --- | --- |
| `const res = await ...` | `const renameOutcome = await renameModule(...)` |
| `const list = rows.filter(...)` | `const archivedModules = moduleRows.filter(...)` |
| `const flag = true` | `const hasUnsavedRename = true` |

## Estado de UI

Antes: `isLoading`, `isError`, `isSuccess` como tres booleanos que pueden estar
todos en `true` a la vez.

Después:

```ts
type RenameState =
  | { status: 'idle' }
  | { status: 'saving' }
  | { status: 'failed'; message: string };
```
