# Incidentes del proxy durante las correcciones (19/10/2026)

Se usa un único proxy `shopify theme dev` hacia el borrador `192125304866`. Cada incidente se clasifica por su síntoma; la causa no se afirma. Los registros por ejecución están en `proxyHealthAfter` e `incidents` de cada `result*.json`.

| Hora (UTC) | Puerto | Síntoma | Clasificación | Qué se hizo |
|---|---|---|---|---|
| 21:51 | 9292 | `GET /` y la ficha responden 200; los tres scripts servidos coinciden con los locales | sano (línea de partida) | Registrado en `antes/proxy-salud-antes.json` |
| 22:08 | 9292 | `GET /products/…` y `GET /` → `302 Location: /password` | `proxy-session-expired (302 /password)`: la sesión de contraseña de la tienda del proxy de la persona dejó de valer (llevaba ~15,5 h abierto) | La primera ejecución de regresiones abortó antes de emitir resultados (`runs/…22-08-31…-regressions-1440x900-dev`, parcial, 0 comprobaciones de comportamiento) |
| 22:09 | 9294 | Se levantó un segundo `theme dev` con la misma tienda y tema (la CLI reutilizó su autenticación; no se pidió ni escribió ninguna contraseña) y respondió 200 | sano | Se usó 9294 mientras 9292 estaba caducado; `proxy-health.mjs` pasó a exigir **exactamente un proxy sano** y a clasificar los demás |
| 22:16 | 9292 | Volvió a responder 200 con el tema esperado | recuperado sin intervención | Se cerró el proceso 9294 (el que levanté yo, pid 29082) para volver a **un solo proxy**; se conservó el 9292 de la persona |

Notas:

- Las ejecuciones `runs/…22-10…` a `…22-16…` con la etiqueta `-dev` son de desarrollo de las pruebas (parciales o con la prueba aún en ajuste) y se leen como tales en `RUNS.md`; no son evidencia de cierre.
- La recuperación de 9292 sin intervención no se explica con los datos disponibles; se registra como observado, sin causa asignada.
