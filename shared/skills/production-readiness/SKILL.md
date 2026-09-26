---
name: production-readiness
description: >-
  Que el código aguante producción: timeouts, reintentos con backoff solo en
  operaciones idempotentes, health checks, apagado ordenado, logs estructurados
  sin secretos y una señal que pruebe que la feature funciona. Úsala cuando
  la tarea agregue o cambie una llamada de red (HTTP, SDK, DB, Redis, cola,
  LLM, webhook), agregue un worker, cron, job o servidor, toque Dockerfile,
  health checks, deploy o config de runtime, o cuando el usuario diga
  "producción", "se cae", "timeout", "lento", "logs", "monitoreo".
---

# Production readiness

El código que funciona en local falla en producción por lo que no se ve en el
diff: una llamada sin timeout, un reintento que duplica un cobro, un deploy que
corta requests a medias. Esta skill cierra esos huecos solo en las llamadas,
jobs y servidores que el pedido agrega o cambia. No endurezcas el resto del repo
ni agregues health checks, logger o métricas que el pedido no necesita.

## Llamadas salientes (HTTP, SDK, DB, Redis, LLM)

- **Timeout explícito en toda llamada.** El default de la librería suele ser
  infinito. Timeout < tiempo máximo del request que la contiene.
- **Reintenta solo lo idempotente** (GET, PUT con la misma clave, o POST con
  `Idempotency-Key`), solo errores transitorios (timeout, 429, 502–504, reset de
  conexión), con backoff exponencial + jitter y tope de intentos. Nunca
  reintentes 4xx de validación ni cobros sin clave de idempotencia.
- **Respeta `Retry-After`** en 429/503.
- **Un cliente compartido por proceso** (pool de conexiones), no uno por request.
- **Falla controlada**: decide qué ve el usuario si la dependencia cae (error
  claro, dato cacheado, feature degradada). Escríbelo; no dejes el stack trace
  como UX.

## Workers, jobs y webhooks

- Todo job es idempotente o deduplica por id: las colas entregan al menos una vez.
- Estado del job persistido (`pending → running → done|failed`), con número de
  intentos y último error. Cola de muertos o estado `failed` visible tras N intentos.
- Webhooks entrantes: verifica firma, responde 2xx rápido y procesa en cola;
  deduplica por el id del evento.
- Crons: un solo ejecutor (lock) si correr dos veces a la vez hace daño.

## Servidores y deploy

- **Health checks separados**: *liveness* (el proceso responde, sin tocar
  dependencias) y *readiness* (puede atender: DB alcanzable, migraciones
  aplicadas). Un liveness que consulta la DB reinicia todo el fleet cuando la DB tiembla.
- **Apagado ordenado**: en `SIGTERM`, deja de aceptar, termina requests/jobs en
  curso con un tope, cierra pools. Sin esto cada deploy corta requests.
- **Config por entorno** validada al arrancar (schema); falta una variable → el
  proceso no arranca, en vez de fallar en la primera request.
- Migraciones compatibles con la versión anterior del código durante el deploy
  (ver `postgres.mdc`).

## Observabilidad

- **Logs estructurados** (JSON o el logger del repo) con nivel, mensaje, id de
  request/job y el id del actor; nunca tokens, contraseñas, PII completa ni
  bodies enteros. Un error se loguea una vez, donde se maneja.
- **Propaga un id de correlación** (header `traceparent` o `x-request-id`) a
  las llamadas salientes y a los jobs.
- **Una señal por feature**: la métrica, log o evento que te diría en producción
  que funciona (conteo de éxitos/fallos, latencia). Si el repo ya tiene
  métricas/tracing, úsalo; no agregues un stack nuevo.

## Verificación

1. Test o prueba manual con la dependencia lenta o caída: respeta el timeout y
   devuelve el error decidido.
2. El reintento no duplica efectos (mismo `Idempotency-Key` → un solo efecto).
3. Si agregaste health checks o shutdown: `curl` a ambos endpoints y un
   `SIGTERM` con una request en curso que termina bien.
4. Lo que no pudiste probar (carga real, failover del proveedor) va como riesgo
   no verificado.
