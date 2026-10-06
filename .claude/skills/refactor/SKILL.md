---
name: refactor
description: Conduce el refactor in situ de Monetta. Elige un WP del plan, lo delega a subagentes Sonnet 5.5 y lo audita contra la matriz de pruebas. Sólo cuando la persona invoca /refactor.
argument-hint: "[estado | siguiente | RF-XX | auditar]"
disable-model-invocation: true
---

# /refactor — bucle orquestador–auditor

Argumentos: `$ARGUMENTS`. Si vienen vacíos, se usa `siguiente`.

Eres la sesión principal: el orquestador y el auditor principal (ver `.claude/CLAUDE.md`).

Antes de actuar, lee:
- `.claude/refactor/PLAN.md`
- `.claude/refactor/MATRIZ_DE_PRUEBAS.md`
- las tres últimas entradas de `.claude/refactor/BITACORA.md`

## Modos

- **`estado`:** muestra una tabla de WPs con su estado, qué los bloquea y las decisiones pendientes, más el último veredicto de la bitácora. No cambia nada.
- **`siguiente`:** toma el primer WP en `pendiente` cuyas dependencias estén `aprobado` o `cerrado` y cuyas decisiones estén `tomada`.
  - **Excepción RF-00:** puede empezar la verificación de entorno, el inventario y la medición de línea base con E1, E2, E3 y E5 pendientes, porque su encargo incluye recogerlas. Consultarlas a la persona mientras se completa el trabajo independiente; no asumir las recomendaciones ni aprobar el WP sin sus decisiones y entregables.
  - Si ninguno cumple, explica qué lo bloquea y haz a la persona la pregunta exacta para desbloquearlo.
- **`RF-XX`:** trabaja ese WP. Verifica antes sus dependencias y decisiones; en RF-00 se aplica la misma excepción de preparación del modo `siguiente`.
- **`auditar`:** audita el diff actual sin delegar: G0 a G5, invariantes y checklist. Sirve después de cambios manuales. Registra la auditoría en la bitácora.

## Bucle por WP

### 1. Preparación

1. Ejecuta `git status --porcelain` y `git rev-parse --short HEAD`.
   - Si el árbol tiene cambios ajenos al WP, detente y pregunta.
2. Si el WP no tiene detalle en `PLAN.md` (fases 4 a 8), escríbelo primero con el formato de la fase 3 y muéstraselo a la persona.
3. Marca el WP como `en curso` en `PLAN.md`.

### 2. Pruebas primero

Si el WP tiene filas OBJ o CAR, encárgalas a `test-engineer` con la plantilla. Al recibir el reporte, comprueba tú mismo:
- **Filas OBJ:** ejecuta la prueba roja y confirma que falla **por la razón descrita**. Si falla por otra causa, el encargo vuelve a `test-engineer`.
- **Filas CAR:** la prueba pasa sobre el código actual.
- **Producción intacta:** `test-engineer` no tocó código de producción. Revísalo con `git diff --stat` y `git diff`.

### 3. Implementación

1. Escribe un encargo autocontenido con `.claude/refactor/PLANTILLA_ENCARGO.md`, dirigido al agente del WP.
2. Si el WP cruza app y backend, divídelo en encargos secuenciales con el mismo fixture de contrato.
3. Invoca al agente y espera su notificación. No hagas sondeo.

### 4. Auditoría

Este paso lo haces tú, nunca el subagente.

1. Ejecuta los gates de la matriz:
   - en cada iteración, G0 a G3;
   - para cerrar el WP, G0 a G5, más G6 a G8 si el WP los requiere.
2. Lee el diff completo con `git diff`.
3. Aplica el checklist de la sección siguiente.
4. Clasifica cada hallazgo como Blocker, Alta, Media o Baja.

### 5. Iteración

Con un hallazgo Blocker o Alta:
1. Devuelve el trabajo al mismo subagente con `SendMessage`, si sigue disponible. Si no, haz un encargo nuevo con la sección «Hallazgos a corregir».
2. Repite como máximo 3 veces. Después, presenta a la persona los hallazgos y las opciones.

### 6. Cierre

1. Actualiza las filas de la matriz con su estado y evidencia.
2. Cambia el WP a `aprobado` en `PLAN.md`.
3. Añade una entrada en `BITACORA.md`.
4. Haz commit sólo si la persona lo autorizó en esta sesión: rama `refactor/rf-XX-<slug>`, y nunca push.

### 7. Reporte a la persona

En pocas líneas:
- WP y veredicto;
- gates, con su resultado literal resumido;
- hallazgos Media y Baja que quedan abiertos;
- decisiones que se necesitan;
- siguiente WP.

## Checklist de auditoría

- **Alcance:** sólo los archivos permitidos. Cualquier cableado extra viene declarado y justificado.
- **Invariantes:** se cumplen los de `CLAUDE.md`. Los que el diff toca tienen una prueba que los demuestra.
- **Pruebas:**
  - verifican comportamiento observable;
  - no usan `skip`, ni `// ignore`, ni dependen de red o reloj real;
  - no debilitan pruebas existentes;
  - llevan en el nombre el ID de la matriz.
- **Conteo:** el número de pruebas es igual o mayor que la base. Si baja, la delta está justificada y registrada.
- **Contratos:** los cambios HTTP son aditivos y el fixture es el mismo en cliente y servidor.
- **Errores:** ninguna excepción cruda en la UI; textos en español; estados distintos para ausencia, sin conexión, servicio caído y sesión vencida.
- **Seguridad:**
  - no hay secretos ni `.env` en el diff;
  - no se registran tokens ni URLs de checkout;
  - el admin sigue autorizado por el servidor.
- **Docs:** si el WP cambia un contrato o la arquitectura, el documento correspondiente se actualiza en el mismo WP.
- **Honestidad:** todo lo que un subagente marcó «no ejecutado» se ejecuta o queda bloqueado. Nunca se da por aprobado.
