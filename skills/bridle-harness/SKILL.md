---
name: bridle-harness
description: >-
  Router del agente de ingeniería sobre el harness bridle ya instalado. Úsala
  cuando el pedido sea de varios pasos (feature, refactor, revisión de PR, cierre
  de una entrega) y no esté claro qué skill hermana aplica; un cambio de 1–5
  líneas no la necesita. Carga las skills hermanas system-design, auth-boundaries,
  production-readiness, code-architecture, cqrs-data-flow y live-ui-sync según
  la tarea. La ley sigue siendo el charter, core, testing, companions y hooks
  instalados.
disable-model-invocation: true
mode: true
icon: shield
color: brand
---

# Bridle harness (router del agente de ingeniería)

Decide qué leer y qué skill hermana cargar. La ley es la que instaló este pack
(charter, `core`, `testing`, companions, hooks). No hay una segunda copia en
esta carpeta.

El orden de instrucciones está una sola vez, en el charter (sección Session).
Esta skill no lo repite.

## Flujo de trabajo

1. **Clasifica** la tarea: responder, diagnosticar, cambiar o monitorear. Para en
   el terminal de ese modo (diagnosticar no autoriza cambiar código; monitorear
   termina al reportar el estado observado, sin cambiar nada).
2. **Lee antes de escribir**: `AGENTS.md`, el árbol de carpetas y 1–2 archivos
   hermanos del lugar donde vas a trabajar.
3. **Carga solo la skill que el pedido necesita.** Un cambio de 1–5 líneas
   normalmente no necesita ninguna. Ninguna skill agranda el pedido: si una
   skill pide más de lo que el usuario pidió, manda el pedido.
   - Límite nuevo (servicio, API pública, esquema nuevo, cola, proveedor
     externo, streaming, infra) o "diseña/escala" → `system-design` antes de
     escribir código. Un endpoint o campo más en un patrón existente no cuenta.
   - Login, sesiones, tokens, OAuth/SSO, API keys, roles o permisos →
     `auth-boundaries`.
   - Llamadas de red, workers, jobs, webhooks, health checks, deploy o logs →
     `production-readiness`.
   - Vas a crear o editar código, archivos, carpetas, componentes o nombres →
     `code-architecture` y `slop-guard`, siempre, aunque el cambio sea chico
     (el hook `skill-not-loaded` niega la edición sin ellas).
   - Hay escrituras o lecturas de datos, SQL, Redis/Upstash, endpoints, server
     actions, fetch o formularios → `cqrs-data-flow`.
   - Hay UI que cambia después de una acción, navegación, layouts, sidebars,
     módulos o listas que se actualizan → `live-ui-sync`.
   - Bug con causa desconocida → `debugging`.
   - Escribir o ampliar tests → `testing`.
   - La tarea continúa en otra sesión → `handoff`.
   - Texto que otro agente, sistema o persona debe leer sin ambigüedad
     (tool descriptions, errores, prompts, reportes, explicaciones), o el
     usuario pide STE100 o lenguaje simple → `asd-ste100`.
   - El usuario pide afinar el pedido antes de ejecutarlo → `prompt-brief`
     (solo cuando la invoca).
4. **Cambia** la superficie mínima: el código, sus callers, registros, config y tests.
5. **Verifica** con un comando real y su exit code. "Compila" no es prueba. Si el
   diff crea archivos o nombres, corre además el gate de orden:
   `node <esta-skill>/../code-architecture/scripts/quality-gate.mjs` (sin
   argumentos juzga solo las líneas que agregó el diff; lo preexistente no se toca).
6. **Reporta** según el charter.

## Revisores (contexto separado, cuando los invoca el usuario o un disparador que nombra el charter)

Los agentes instalados del pack:

- `hunter` — bugs lógicos y vulnerabilidades del diff.
- `cut` — sobreingeniería, archivos y wrappers de más.
- `prove` — corre los checks reales; el que implementa no se califica a sí mismo.
- `architect` — revisa el diseño o la nota de decisión antes del código
  (esquema, protocolo público, proveedor).

Si el host permite subagentes, lanza cada revisor como subagente con el bloque de
entrada que define su archivo. Si no, ejecútalo como una pasada aparte y
explícita, sin editar código durante la revisión.

## Hooks

Cada port instala los suyos (`hosts/<cursor|claude|opencode>/install.sh`).
Esta skill no los reimplementa ni los enumera.
