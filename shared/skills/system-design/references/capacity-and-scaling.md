# Capacidad y escalera de escalado

## Números de servilleta

| Magnitud | Cuenta |
| --- | --- |
| QPS promedio | usuarios activos/día × acciones/usuario/día ÷ 86 400 |
| QPS pico | promedio × 2–5 (tráfico diario) o × 10 (lanzamientos, eventos) |
| Almacenamiento/año | escrituras/día × bytes por fila (con índices ≈ ×2) × 365 |
| Ancho de banda | QPS pico × bytes por respuesta |
| Conexiones | usuarios concurrentes × conexiones abiertas (streaming cuenta cada una) |

Referencias rápidas para ordenar magnitudes, no para prometer SLAs:

- Un día ≈ 10⁵ s. 1 M requests/día ≈ 12 QPS promedio.
- Lectura de RAM ≈ 100 ns; SSD ≈ 100 µs; ida y vuelta en la misma región ≈ 0,5–1 ms;
  entre continentes ≈ 100–150 ms.
- Una primaria de Postgres bien indexada en hardware moderno: miles a decenas de
  miles de queries simples por segundo. Mide con `EXPLAIN` antes de creer que no alcanza.

Escribe cada número con su supuesto: `12 QPS (1 M req/día, supuesto)`.

## Escalera (sube un peldaño solo cuando el número lo exige)

1. **Un servidor + una base de datos.** App sin estado, DB gestionada, backups.
2. **Vertical.** Más CPU/RAM a la DB y a la app. Barato y sin código nuevo.
3. **Índices y queries.** `EXPLAIN` sobre las 5 queries más frecuentes antes que cualquier cache.
4. **Horizontal en la app.** Varias instancias sin estado detrás de un
   balanceador con health checks. Sesiones fuera del proceso.
5. **Pooler de conexiones** (PgBouncer, Supavisor) cuando hay muchas instancias o serverless.
6. **Cache de lectura** (Redis) para lecturas calientes con TTL e invalidación
   explícita (`cqrs-data-flow`). **CDN** para estáticos y respuestas públicas.
7. **Réplicas de lectura** cuando las lecturas saturan la primaria. Decide qué
   lecturas toleran lag de réplica; las del propio usuario tras escribir van a la primaria.
8. **Colas y workers** para trabajo lento o reintentable (emails, webhooks,
   inferencia, reportes). La request responde rápido y el job reporta estado.
9. **Mover cargas de escritura pesadas** a otro store (logs, eventos, métricas)
   antes que shardear el dominio principal.
10. **Sharding / particionado** solo del conjunto que crece sin límite, con la
    clave de partición elegida por el patrón de acceso. Último recurso.

## SPOF

Lista cada componente con una sola instancia (DB primaria, cola, balanceador,
proveedor externo). Para cada uno: ¿failover gestionado, redundancia, o
degradación aceptada y escrita? "Aceptado por ahora" es válido si queda en la nota.
