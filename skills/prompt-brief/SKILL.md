---
name: prompt-brief
description: >-
  Convierte un pedido suelto en un brief preciso antes de ejecutarlo: objetivo,
  archivos, límites, fuera de alcance y el comando que prueba que está hecho.
  Solo cuando el usuario la invoca (/prompt-brief, "afina este prompt", "arma
  el brief"). No ejecuta el trabajo hasta que el usuario apruebe el brief.
disable-model-invocation: true
---

# Prompt brief

Un modelo hace de más cuando el pedido deja huecos: no sabe dónde parar, así
que rellena. Esta skill cierra los huecos **antes** de tocar código. El brief es
corto a propósito: cada línea le quita al modelo una decisión que no le toca.

## Proceso

1. **Lee lo mínimo para aterrizar el pedido**: `AGENTS.md` y los archivos que el
   pedido nombra o que un `grep` del símbolo encuentra. No explores el repo.
2. **Escribe el brief** con la plantilla de abajo. Cada campo sale del pedido o
   del código leído; lo que asumas va marcado `(supuesto)`.
3. **Pregunta solo lo que cambia el trabajo**: máximo 2 preguntas, cada una con
   la opción que recomiendas. Si nada es ambiguo, no preguntes.
4. **Para.** Muestra el brief y espera "sí", un ajuste o un "no". No edites nada
   antes de eso. Con el "sí", ejecuta exactamente el brief bajo `core` y `testing`.

## Plantilla

```
Objetivo: <un resultado observable, una frase>
Contexto: <por qué se pide, si cambia cómo se hace>
Archivos: <rutas exactas que se tocan; "nuevo:" para los que se crean>
Hacer:
  - <paso concreto>
Límites:
  - <convención del repo, API o patrón que se respeta>
Fuera de alcance: <lo cercano que NO se toca: refactors, renombres, otras pantallas>
Hecho cuando: <comando + exit esperado, o el recorrido de UI que lo demuestra>
Supuestos: <lista corta, o "ninguno">
```

## Reglas de un buen brief

- **Positivo y concreto**: "usa el `Result` de `platform/result.ts`" en vez de
  "no inventes otro formato". Di qué hacer; las prohibiciones van solo en
  "Fuera de alcance".
- **Un objetivo por brief.** Si el pedido trae dos, propone dos briefs en orden.
- **Archivos con ruta**, no "el componente del sidebar". Si no se sabe cuál es,
  el primer paso de "Hacer" es encontrarlo y el brief lo dice.
- **"Hecho cuando" es verificable**: un comando que puede fallar, no "que funcione".
- **El porqué va en Contexto** cuando cambia la solución ("el cliente móvil
  depende de este campo" → no se renombra).
- **Nada que el usuario no pidió.** Si ves una mejora, va como una línea después
  del brief ("Aparte: …"), nunca dentro de "Hacer".

## Por tipo de pedido

| Tipo | Agrega al brief |
| --- | --- |
| Bug | Síntoma exacto, cómo reproducirlo y el test `regression:` que falla antes y pasa después. Sin causa conocida → primero `debugging`. |
| Feature | El caso feliz y 1–2 casos borde que sí entran; el resto en "Fuera de alcance". |
| Refactor | Qué comportamiento no cambia y el comando que lo prueba antes y después. |
| Review | Qué diff, y qué revisor corre (`hunter`, `cut`, `architect`). Sin edits. |
| Diseño | Remite a `system-design`; el brief pide la nota de decisión, no código. |

## Ejemplo

Pedido: "arregla que el sidebar no se actualiza al renombrar un módulo".

```
Objetivo: al renombrar un módulo, el sidebar muestra el nombre nuevo sin recargar.
Contexto: hoy hay que presionar F5 (reportado por el usuario).
Archivos: features/modules/commands/rename-module.command.ts
Hacer:
  - Invalidar el tag del listado de módulos después del commit del rename.
Límites:
  - Mismo mecanismo de invalidación que usan los otros commands de modules.
Fuera de alcance: rediseño del sidebar, otros commands, estilos.
Hecho cuando: test del command verifica la invalidación; recorrido manual renombra y el sidebar cambia sin petición de documento.
Supuestos: el sidebar lee de list-modules.query.ts (supuesto, confirmado al leer).
```
