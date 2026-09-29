# Dónde va cada cosa

Pregunta en orden y detente en la primera que sea "sí".

1. ¿El framework exige un nombre/ubicación (page.tsx, layout.tsx, route.ts,
   middleware.ts)? → Ahí, y el archivo solo compone: importa de `features/`.
2. ¿Pertenece a un dominio del negocio (módulos, facturas, usuarios)? →
   `features/<dominio>/`.
   - Valida o describe la forma del dato → `<dominio>.schema.ts`
   - Toca SQL → `<dominio>.repository.ts`
   - Cambia estado → `commands/<verbo>-<objeto>.command.ts`
   - Lee estado → `queries/<lista|obtener>-<objeto>.query.ts`
   - Claves/TTL de cache → `<dominio>.cache.ts`
   - UI de ese dominio → `components/<dominio>-<pieza>.tsx`
   - Hook de cliente de ese dominio → `components/use-<dominio>-<cosa>.ts`
3. ¿Es infraestructura sin dominio (cliente DB, cliente Redis, env, logger,
   Result)? → `platform/<cosa>.ts`.
4. ¿Es una primitiva visual reutilizable sin conocimiento de negocio? → `ui/`.
5. ¿Ninguna de las anteriores? Probablemente estás creando una abstracción
   especulativa. Escribe el código donde se usa; extrae solo cuando haya un
   segundo caller real.

## Cuándo dividir una feature

- Más de ~12 archivos en `components/` → subcarpetas por pantalla
  (`components/module-settings/…`).
- Dos features comparten un concepto → ese concepto es su propio dominio, no un
  `shared/` genérico.

## Monorepo

`apps/<app>/` con la misma estructura interna; `packages/<dominio-o-infra>/`
solo cuando dos apps lo consumen de verdad. Resuelve siempre el `package.json`
dueño del archivo antes de elegir framework o gestor.

## Migrar un repo desordenado

No reestructures todo en una tarea. Mueve solo lo que tocas, deja el resto, y
anota en el reporte qué quedó pendiente. Mover archivos cambia imports de otros:
lista los callers afectados junto a la prueba.
