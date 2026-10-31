# Plantilla de encargo para subagentes

El subagente **no ve la conversación**. Todo lo que necesita debe estar en el encargo. Copia esta plantilla, rellénala y bórrale las secciones que no apliquen.

---

**WP:** RF-XX — título
**Agente:** flutter-implementer | backend-implementer | test-engineer
**Iteración:** 1 (desde la 2, incluye «Hallazgos a corregir»)

## Objetivo

Una o dos frases que describan el resultado observable.

## Contexto verificado

Hechos con `archivo:línea`, tomados del plan, de la revisión o de tu lectura del código. Sin interpretaciones.

- …

## Alcance permitido

Archivos y directorios exactos que el subagente puede crear o modificar.

- …

## Fuera de alcance

Todo lo demás. Menciona en especial:

- …

## Invariantes afectados

IDs de `.claude/refactor/MATRIZ_DE_PRUEBAS.md` y cómo debe seguir demostrándose cada uno.

- INV-xx: …

## Pruebas requeridas

- ID de la matriz, qué debe demostrar y su tipo (caracterización, roja o contrato).
- Si ya existe una prueba roja: su ruta y el fallo esperado.

## Decisiones ya tomadas que aplican

- Por ejemplo: E-T1 = (b), tope global 1.5 y titulares 1.2.

## Verificación que debes ejecutar

Comandos exactos, en orden.

## Criterios de aceptación

- [ ] …

## Hallazgos a corregir

Sólo desde la iteración 2.

- [Severidad] `archivo:línea` — hallazgo — corrección esperada.

## Formato del reporte

El de tu archivo de agente, sin omitir secciones.

---

**Antes de enviar el encargo, el orquestador comprueba:**

- [ ] Las decisiones requeridas están `tomada` en `PLAN.md`.
- [ ] Las dependencias del WP están `aprobado` o `cerrado`.
- [ ] El árbol está limpio, o sólo contiene cambios de este mismo WP.
- [ ] Las líneas citadas siguen siendo correctas. Si el código cambió, vuelve a leerlo.
