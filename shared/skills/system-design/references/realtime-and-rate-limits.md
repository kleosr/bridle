# Realtime y rate limits

## Elegir transporte

| Necesidad | Usa | Por qué |
| --- | --- | --- |
| Servidor → cliente, un flujo por request (respuesta de un LLM, progreso de un job) | **SSE** (`text/event-stream`) | HTTP normal: pasa por proxies y CDN, reconexión con `Last-Event-ID`, sin estado de socket. |
| Bidireccional de baja latencia (chat multiusuario, colaboración, juegos) | **WebSocket** | Un canal full-duplex; exige sticky sessions o pub/sub entre instancias. |
| Cambios poco frecuentes, pocos usuarios | **Polling** o refetch al enfocar | Cero infraestructura. |
| Otros usuarios deben ver el cambio | Pub/sub (Redis, servicio realtime) detrás de SSE/WS | Las instancias no comparten memoria. |

Reglas:

- Streaming de respuestas de LLM → SSE por defecto. WebSocket solo si el
  cliente también envía datos durante el stream.
- Cada conexión abierta cuenta en capacidad y en el límite del proveedor
  serverless (timeouts de función). Verifica el tiempo máximo de respuesta del host.
- Persiste el resultado final al terminar el stream, no por cada chunk. Si el
  cliente se desconecta, decide explícitamente si el trabajo sigue o se cancela.
- Heartbeat/comentario SSE cada ~15–30 s para que proxies no corten la conexión.

## Rate limiting

- **Limita por la unidad que cuesta**: tokens de LLM, bytes subidos, jobs
  encolados, minutos de cómputo. Contar requests deja pasar una request que
  cuesta 1000× otra.
- **Clave del límite**: usuario autenticado > API key > IP. IP sola solo para
  endpoints anónimos.
- **Algoritmo**: token bucket o sliding window en un store compartido (Redis),
  no en memoria del proceso.
- **Respuesta**: `429` con `Retry-After`; en APIs públicas, headers
  `RateLimit-Limit` / `RateLimit-Remaining` / `RateLimit-Reset`.
- **Presupuestos por plan** (free/pro) en config, no en `if` dispersos.
- Límite de concurrencia (streams simultáneos por usuario) además del límite por tiempo.
