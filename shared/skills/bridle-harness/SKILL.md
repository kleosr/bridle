---
name: bridle-harness
description: >-
  Router del agente de ingeniería sobre el harness bridle ya instalado. Úsala
  SIEMPRE que se vaya a escribir, modificar, revisar, depurar o terminar código
  en un repo (features, refactors, bugs, "crea un sidebar", "agrega un módulo",
  "conecta Redis", "revisa mi PR", "por qué falla"), aunque el usuario no la
  nombre. Carga las skills hermanas code-architecture, cqrs-data-flow y
  live-ui-sync según la tarea. La ley sigue siendo el charter, core, testing,
  companions y hooks instalados.
---

# Bridle harness (router del agente de ingeniería)

Decide qué leer y qué skill hermana cargar. La ley es la que instaló este pack
(charter, `core`, `testing`, companions, hooks). No hay una segunda copia en
esta carpeta.

## Orden de instrucciones (de mayor a menor)

1. Instrucciones del host y del usuario.
2. Charter instalado (`kleosr.mdc` en Cursor; el port del host en los demás).
3. `SECURITY.md` solo en preguntas de límites o secretos.
4. Ley siempre activa: `core` y `testing`.
5. Companions de stack, solo si el `package.json` dueño del archivo lo confirma:
   `next`, `vite` sin next, `astro`, instalaciones JS → `pnpm`, SQL → `postgres`,
   Supabase → `supabase`.
6. Skills hermanas (abajo) y revisores cuando se invocan.

`AGENTS.md` del repo gana solo en convenciones locales. Si dos instrucciones
obligatorias chocan, di cuál seguiste.

## Flujo de trabajo

1. **Clasifica** la tarea: responder, diagnosticar, cambiar o monitorear. Para en
   el terminal de ese modo (diagnosticar no autoriza cambiar código).
2. **Lee antes de escribir**: `AGENTS.md`, el árbol de carpetas y 1–2 archivos
   hermanos del lugar donde vas a trabajar. Lee `core` y `testing` completos
   la primera vez en la sesión.
3. **Carga las skills que aplican** (pueden ser varias):
   - Vas a crear archivos, carpetas, componentes o nombrar cosas → `code-architecture`.
   - Hay escrituras o lecturas de datos, SQL, Redis/Upstash, endpoints, server
     actions, fetch o formularios → `cqrs-data-flow`.
   - Hay UI que cambia después de una acción, navegación, layouts, sidebars,
     módulos o listas que se actualizan → `live-ui-sync`.
   - Bug con causa desconocida → `debugging`.
   - Escribir o ampliar tests → `testing`.
   - La tarea continúa en otra sesión → `handoff`.
4. **Cambia** la superficie mínima: el código, sus callers, registros, config y tests.
5. **Verifica** con un comando real y su exit code. "Compila" no es prueba. Corre
   además el gate de orden:
   `node <esta-skill>/../code-architecture/scripts/quality-gate.mjs` (sin
   argumentos revisa los archivos cambiados en git).
6. **Reporta**: resultado, archivos, prueba (comando + exit), riesgo no verificado.
   Sin preámbulo ni ofertas al final.

## Revisores (contexto separado, solo cuando se piden o antes de cerrar algo grande)

Los agentes instalados del pack:

- `hunter` — bugs lógicos y vulnerabilidades del diff.
- `cut` — sobreingeniería, archivos y wrappers de más.
- `prove` — corre los checks reales; el que implementa no se califica a sí mismo.

Si el host permite subagentes, lanza cada revisor como subagente con el bloque de
entrada que define su archivo. Si no, ejecútalo como una pasada aparte y
explícita, sin editar código durante la revisión.

## Hooks

Los cuatro hooks (prompt, shell, lectura, stop) los instala el pack
(`bash scripts/install.sh` en el repo bridle). Esta skill no los reimplementa.
