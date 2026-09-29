---
name: code-architecture
description: >-
  Orden, estructura de carpetas y nombres NO genéricos para código generado por
  IA. Úsala antes de crear un archivo, carpeta, componente, hook, función,
  tipo o variable nueva. Aplica solo a lo que el pedido crea. Evita App.tsx,
  utils.ts, helpers.ts, Component.tsx, handleClick, data, item y cualquier nombre
  que no diga qué dominio toca ni qué rol cumple. Aplica también cuando el usuario
  diga "ordena", "limpia", "está muy genérico", "estructura el proyecto",
  "crea un módulo/sidebar/página", aunque no mencione arquitectura.
---

# Code architecture

El código genérico se ve igual en cualquier proyecto y por eso no dice nada del
tuyo. La regla de fondo: **cada nombre debe responder "qué dominio" y "qué rol"**,
y cada archivo debe vivir donde otro desarrollador lo buscaría primero.

**Alcance:** esta skill da forma al código que el pedido crea. No renombra, no
mueve ni reestructura código existente que el pedido no nombra; lo que veas
mejorable va en una línea del reporte.

## 1. Antes de escribir (obligatorio)

1. Lista el árbol de la zona donde vas a trabajar (2 niveles).
2. Abre 1–2 archivos hermanos y anota: casing de archivos (kebab/Pascal), tipo de
   export (named/default), sufijos usados, dónde van los tipos y los tests.
3. **Si el repo ya tiene convención, esa manda**, aunque difiera de esta skill.
   Solo aplica la estructura por defecto (sección 3) en proyectos nuevos o en
   zonas sin precedente, y dilo en una línea.
4. Nunca crees un archivo que ya existe con otro nombre: busca por símbolo antes
   (`grep`/búsqueda semántica) para no duplicar lógica.

## 2. Nombres

Fórmula: `<dominio>-<cosa>.<rol>.ts(x)` para archivos, `verboDominioObjeto` para
funciones, `sustantivoDominio` para datos.

| Genérico (prohibido) | Con intención |
| --- | --- |
| `App.tsx` nuevo, `Main.tsx`, `Component.tsx` | `workspace-shell.tsx`, `billing-page.tsx` |
| `utils.ts`, `helpers.ts`, `common.ts`, `lib.ts`, `misc.ts` | `format-currency.ts`, `parse-invoice-csv.ts` |
| `types.ts` gigante en la raíz | tipos junto a su feature: `features/modules/module.schema.ts` |
| `service.ts`, `manager.ts`, `handler.ts` | `create-module.command.ts`, `list-modules.query.ts` |
| `handleClick`, `onSubmit` sin objeto | `archiveModule`, `submitModuleRename` |
| `data`, `result`, `res`, `item`, `obj`, `temp`, `value` | `moduleRows`, `renameOutcome`, `activeModule` |
| `newSidebar`, `Sidebar2`, `SidebarFinal`, `MySidebar` | `workspace-sidebar.tsx` (reemplaza, no dupliques) |
| `isLoading`, `isError`, `isSuccess` paralelos | una unión: `status: 'idle' \| 'saving' \| 'failed'` |
| `const API_URL` repetido en 5 archivos | una constante en `platform/env.ts` validada |

`App.tsx`, `index.ts`, `page.tsx`, `layout.tsx`, `route.ts` solo se permiten
cuando el framework los exige por convención de enrutado o entrada. Los barrels
(`index.ts` que reexporta) solo en el límite público de una feature, nunca para
"importar todo".

## 3. Estructura por defecto (proyectos sin convención)

Organiza **por feature (dominio), no por tipo técnico**. Un `components/` global
con 80 archivos es el síntoma que estamos evitando.

```
src/
  app/                              # solo enrutado del framework (delgado)
    (workspace)/layout.tsx          # shell persistente: sidebar vive aquí
    (workspace)/modules/page.tsx    # compone la feature, no tiene lógica
  features/
    modules/                        # un dominio
      module.schema.ts              # zod: forma y validación del dominio
      module.repository.ts          # SQL del agregado (único lugar con SQL)
      module.cache.ts               # claves y TTL de Redis de este dominio
      commands/create-module.command.ts
      commands/rename-module.command.ts
      queries/list-modules.query.ts
      components/module-list.tsx
      components/module-rename-form.tsx
      module.test.ts
  platform/                         # infraestructura compartida, sin dominio
    db-client.ts
    redis-client.ts
    env.ts
    result.ts                       # tipo Result/DomainError común
  ui/                               # primitivas visuales sin dominio (button, dialog)
```

Reglas de dependencia: `app → features → platform/ui`. Una feature no importa
internos de otra; si lo necesita, usa la query/command pública de esa feature.
`platform` nunca importa de `features`. Ver `references/placement.md` para decidir
dónde va cada cosa y cómo escalar a monorepo.

## 4. Código dentro del archivo

- Un trabajo por módulo. Si describirlo necesita "y", son dos archivos.
- Returns tempranos en vez de `if` anidados. Complejidad ciclomática ≤ 22.
- Exports nombrados salvo que el framework exija default.
- Sin `any`, sin casts ciegos: estrecha `unknown` con el schema zod.
- Errores a propósito: resultado tipado (`platform/result.ts`), no `try/catch`
  que traga y hace `console.log`.
- Comentarios solo para el porqué, una restricción externa o un contrato. Nada de
  narrar ("// obtenemos los datos"), banners ni código comentado.
- Sin strings mágicos repetidos: rutas, claves de cache y eventos como constantes
  en su feature.
- Tamaño: ~80 líneas es la preferencia de cohesión; 300 es el máximo duro para
  archivos nuevos escritos a mano.

Ejemplos antes/después completos en `references/naming-examples.md`.

## 5. Gate antes de decir "listo"

Corre desde la raíz del repo:

```bash
node <ruta-de-esta-skill>/scripts/quality-gate.mjs            # archivos cambiados en git
node <ruta-de-esta-skill>/scripts/quality-gate.mjs src/features  # rutas explícitas
```

Sin rutas, el gate juzga solo las líneas que agregó el diff y los archivos
nuevos; lo preexistente se cuenta aparte y no se corrige. Detecta nombres de
archivo genéricos, identificadores genéricos, recargas duras,
`any`, SQL concatenado, `SELECT *`, `set` de Redis sin TTL, TODOs sin dueño,
`console.log` y archivos de más de 300 líneas. Exit 1 = hay errores que corregir
antes de reportar. Las advertencias se revisan, no se ignoran en silencio: si una
es intencional, dilo en el reporte con el porqué.
