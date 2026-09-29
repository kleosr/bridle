---
name: system-design
description: >-
  Diseño antes de código, como un senior: requisitos, no funcionales con
  números, capacidad, la arquitectura más simple que los cumple, fallos y una
  nota de decisión. Úsala cuando el usuario diga "diseña", "arquitectura",
  "escala", "cuánto aguanta", "millones de usuarios", "system design", o cuando
  la tarea cree un límite nuevo: servicio, API pública, esquema de datos nuevo,
  cola, proveedor externo, streaming/realtime o infraestructura. No para un
  endpoint, campo o tabla más que sigue un patrón que el repo ya tiene. No
  autoriza sobreingeniería.
---

# System design

Un mid-level abre el editor. Un senior primero pregunta **qué tiene que aguantar
esto** y elige lo más simple que lo aguanta. Esta skill produce una nota de
decisión corta antes de escribir código, y nada más grande que eso.

## Cuándo no aplica

Cambios que no crean un límite nuevo: UI, refactor local, bug con causa
conocida, o un endpoint/campo/tabla más siguiendo el patrón existente. Ahí haz
el cambio directo. Tampoco reescribas un diseño existente que el pedido no pide
cambiar: la nota cubre solo lo nuevo.

## Proceso (en este orden, no te saltes pasos)

1. **Requisitos funcionales**: 3–5 verbos del usuario ("envía mensaje", "ve su
   historial"). Lo que no está en la lista queda fuera del diseño.
2. **No funcionales con números**: latencia (p50/p99), disponibilidad, QPS de
   lectura y escritura, tamaño y crecimiento de datos, consistencia requerida
   (fuerte o eventual, por operación). Sin número conocido → asume uno,
   escríbelo como supuesto y sigue. Pregunta solo si el supuesto cambia la
   arquitectura.
3. **Capacidad en servilleta**: `references/capacity-and-scaling.md`. Una línea
   por recurso: QPS pico, almacenamiento a 1 año, ancho de banda, conexiones.
4. **Arquitectura mínima**: sube por la escalera de
   `references/capacity-and-scaling.md` solo hasta el peldaño que los números
   exigen. Cada componente nuevo (cache, cola, réplica, CDN, servicio) necesita
   el número que lo justifica.
5. **Fallos**: por cada componente, ¿qué pasa si cae o se pone lento? Nombra los
   SPOF, el timeout, el comportamiento degradado y qué ve el usuario. Detalle de
   implementación en `production-readiness`.
6. **Seguridad del límite**: quién llama, cómo se autentica, qué puede tocar.
   Si hay login, tokens o permisos → `auth-boundaries`.
7. **Costo**: la pieza más cara (GPU, egress, DB) y su orden de magnitud al mes.
8. **Nota de decisión** (abajo) antes del primer archivo de código.

## Reglas duras

- **No escales antes del número.** Nada de microservicios, Kubernetes, sharding,
  event sourcing ni multi-región sin un requisito medido que lo pida. Un
  Postgres primario con réplicas de lectura aguanta mucho más de lo que se cree
  (ChatGPT sirve cientos de millones de usuarios con una primaria sin shardear).
- **Lectura y escritura se escalan distinto.** Lecturas: índices, cache,
  réplicas. Escrituras: batching, colas, particionar solo lo que crece sin
  límite. Nombra cuál de las dos es el cuello.
- **Todo lo que crece sin límite tiene plan**: paginación por cursor, TTL,
  retención o archivado. Tablas append-only sin plan son un bug a 1 año.
- **Estado fuera del proceso.** Servidores de app sin estado detrás del
  balanceador; sesiones, locks y colas en un store compartido.
- **Realtime y límites con la unidad correcta**: SSE vs WebSocket vs polling y
  rate limit por la unidad de costo real (tokens, bytes, jobs), no por request.
  Ver `references/realtime-and-rate-limits.md`.
- **Un contrato por borde**: API pública con versionado e idempotencia según
  `cqrs-data-flow/references/request-contract.md`.

## Nota de decisión (5–15 líneas, en el PR o en `docs/decisions/` si existe)

```
Decisión: <qué construimos, una frase>
Requisitos: <funcionales clave>
No funcionales: <p99, QPS, datos/año, disponibilidad> (supuestos marcados)
Capacidad: <números de servilleta>
Diseño: <componentes y por qué cada uno>
Descartado: <la alternativa más fuerte y por qué no ahora>
Fallos: <SPOF, timeouts, degradación>
Revisar cuando: <el número que obliga a subir un peldaño>
```

No crees `docs/decisions/` si el repo no lo tiene: la nota va en el PR o en el
reporte. Para decisiones grandes o irreversibles (esquema, proveedor, protocolo
público), pide el revisor `architect` antes de implementar.

## Verificación

- Cada componente del diseño apunta a un número o requisito. Si no, se borra.
- La nota existe y dice qué número dispara el siguiente peldaño.
- La implementación posterior sigue `core` y `testing`; el diseño no es prueba.
