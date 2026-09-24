---
name: live-ui-sync
description: >-
  UI que se actualiza sola después de cada acción, sin recargar la página ni
  tener que presionar F5. Úsala SIEMPRE que se cree o modifique UI que cambia tras
  una mutación, navegación entre secciones, layouts, sidebars, menús, módulos,
  tabs, listas, tablas, formularios, modales o dashboards; y cuando el usuario diga
  "tengo que recargar", "no se actualiza", "se ve feo al refrescar", "parpadea",
  "pierde el estado", aunque no mencione caching. Prohíbe location.reload,
  navegación dura y remounts forzados.
---

# Live UI sync

Cuando la IA no sabe cómo avisarle a la UI que un dato cambió, recarga toda la
página. Eso borra el estado, parpadea y oculta el bug real: **faltaba una
invalidación**. Esta skill obliga a cerrar el ciclo mutación → datos frescos
→ UI, sin tocar el documento.

## Prohibido (el gate lo marca como error)

- `window.location.reload()`, `location.href = '/ruta-interna'`,
  `location.assign/replace` para rutas propias.
- `<a href="/interna">` en vez del `Link` del framework.
- `key={Math.random()}` / `key={Date.now()}` para "forzar" un re-render.
- `router.push(rutaActual)` como truco para refrescar.
- `export const dynamic = 'force-dynamic'` o `cache: 'no-store'` en todas partes
  para tapar una invalidación que falta (solo con justificación escrita).
- Sidebar o shell dentro de `page.tsx`: se desmonta en cada navegación.

## Decide cómo se refresca (en este orden)

Detecta primero qué usa el repo (Next App Router, TanStack Query, SWR, Remix,
Vite SPA) leyendo `package.json` y 1–2 features existentes. No agregues una
librería de datos si ya hay una.

1. **Server Components + server actions (Next App Router)**: el command invalida
   con `revalidateTag(tag)` o `revalidatePath(ruta)` dentro de la action; Next
   re-renderiza el RSC en la misma respuesta. No hace falta nada en el cliente.
2. **Cliente con TanStack Query / SWR**: en `onSuccess` de la mutación,
   `queryClient.setQueryData` con el DTO que devolvió el command (instantáneo) y/o
   `invalidateQueries({ queryKey })` (refetch en segundo plano). Las query keys
   salen de una fábrica por feature, igual que las claves de Redis.
3. **Optimista** cuando la acción es frecuente y casi siempre exitosa (renombrar,
   reordenar, toggle): `useOptimistic` o `onMutate` + rollback en `onError`.
4. **`router.refresh()`** solo si hay Server Components que dependen del cambio y
   no hay tag/ruta más fina. Es un refresco suave (no recarga el documento ni
   pierde estado de cliente), pero re-pide todo el árbol: úsalo como último recurso.
5. **Otros usuarios/pestañas**: refetch al enfocar la ventana o por intervalo,
   SSE o servicio realtime. Ver `cqrs-data-flow/references/redis-upstash.md`.

El cache de servidor (Redis) y el de cliente/framework son capas distintas: el
command debe invalidar **las dos**. Ese es el origen típico de "en la DB está pero
en pantalla no".

## Layouts, sidebars y módulos

Patrón completo en `references/sidebar-modules.md`. Lo esencial:

- El sidebar vive en el `layout` del grupo de rutas; persiste entre navegaciones.
- La lista de módulos viene de una query (o un registro estático tipado), no
  hardcodeada en el JSX.
- El item activo se deriva de `usePathname()`/params, no de un `useState`.
- Filtros, tab activa y paginación en `searchParams`: sobreviven a recargas,
  se comparten por URL y no necesitan estado global.
- Módulos pesados con carga diferida (`next/dynamic` / `React.lazy`) y un
  `loading.tsx` o `Suspense` por módulo, para que el shell nunca parpadee.

## Estados de carga sin parpadeo

- `Suspense` + `loading.tsx` por segmento, no un spinner de pantalla completa.
- Pendiente de la mutación con `useFormStatus` / `useTransition` /
  `isPending` de la mutación, deshabilitando solo el control afectado.
- Errores del command (`ok:false`) se muestran junto al campo con `fieldErrors`;
  nunca se "resuelven" recargando.

## Verificación (obligatoria para UI)

1. Recorre el flujo real: crea/edita/borra y confirma que la lista, el sidebar y
   los contadores cambian **sin F5**.
2. En DevTools → Network, filtra por "Doc": tras la acción no debe aparecer una
   nueva petición de documento.
3. El estado de cliente (scroll, sidebar colapsado, input a medio escribir en
   otro panel) sigue igual después de la acción.
4. `quality-gate.mjs` sin errores `hard-reload`, `hard-navigation`, `remount-key`.

Si no hay navegador disponible para recorrer el flujo, dilo como riesgo no
verificado en el reporte; no lo declares hecho.
