---
name: bridle-harness
description: >-
  Router del agente de ingeniería sobre el harness bridle ya instalado. Úsala
  SIEMPRE que se vaya a escribir, modificar, revisar, depurar o terminar código
  en un repo (features, refactors, bugs, "crea un sidebar", "agrega un módulo",
  "conecta Redis", "revisa mi PR", "por qué falla"), aunque el usuario no la
  nombre. Carga las skills hermanas system-design, auth-boundaries,
  production-readiness, code-architecture, cqrs-data-flow y live-ui-sync según
  la tarea. La ley sigue siendo el charter, core, testing, companions y hooks
  instalados.
---

# Bridle harness (router del agente de ingeniería)

Decide qué leer y qué skill hermana cargar. La ley es la que instaló este pack
(charter, `core`, `testing`, companions, hooks). No hay una segunda copia en
esta carpeta.

El orden de instrucciones está una sola vez, en el charter (sección Session).
Esta skill no lo repite.

## Flujo de trabajo

1. **Clasifica** la tarea: responder, diagnosticar, cambiar o monitorear. Para en
   el terminal de ese modo (diagnosticar no autoriza cambiar código).
2. **Lee antes de escribir**: `AGENTS.md`, el árbol de carpetas y 1–2 archivos
   hermanos del lugar donde vas a trabajar. Lee `core` y `testing` completos
   la primera vez en la sesión.
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
   - Vas a crear archivos, carpetas, componentes o nombrar cosas → `code-architecture`.
   - Hay escrituras o lecturas de datos, SQL, Redis/Upstash, endpoints, server
     actions, fetch o formularios → `cqrs-data-flow`.
   - Hay UI que cambia después de una acción, navegación, layouts, sidebars,
     módulos o listas que se actualizan → `live-ui-sync`.
   - Bug con causa desconocida → `debugging`.
   - Escribir o ampliar tests → `testing`.
   - La tarea continúa en otra sesión → `handoff`.
   - El usuario pide afinar el pedido antes de ejecutarlo → `prompt-brief`
     (solo cuando la invoca).
4. **Cambia** la superficie mínima: el código, sus callers, registros, config y tests.
5. **Verifica** con un comando real y su exit code. "Compila" no es prueba. Corre
   además el gate de orden:
   `node <esta-skill>/../code-architecture/scripts/quality-gate.mjs` (sin
   argumentos juzga solo las líneas que agregó el diff; lo preexistente no se toca).
6. **Reporta**: resultado, archivos, prueba (comando + exit), riesgo no verificado.
   Sin preámbulo ni ofertas al final.

## Revisores (contexto separado, solo cuando se piden o antes de cerrar algo grande)

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

Los tres hooks (prompt, shell, lectura) los instala el pack en Cursor
(`bash scripts/install.sh`) y opencode; el port de Claude Code no instala hooks.
Esta skill no los reimplementa.
