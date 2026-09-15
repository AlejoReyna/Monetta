# Segunda reauditoría de correcciones A–D

## Veredicto

Revisión del árbol local el 14 de septiembre de 2026. R2, R3 y R4 quedan cerrados en el alcance comprobado. Los dos probes de la primera reauditoría pasan. R1 corrige la pérdida inmediata en memoria, pero queda parcialmente abierto por persistencia: el resultado de combinar restauración y mutaciones no se guarda al finalizar la carga.

No se modificó código de implementación ni tests del proyecto. Las reproducciones adicionales se ejecutaron desde temporales; su código queda como evidencia textual.

## Hallazgo pendiente

### P2 — El historial corregido en memoria no coincide con el restaurado tras reiniciar

Ubicación principal: `lib/features/catalog/search_history.dart:138`. Después de `_mergeRestore`, `setScope` marca el estado como hidratado, limpia las marcas de eliminación y notifica, sin persistir el resultado.

Dos caminos contribuyen al mismo problema:

- `forget` durante una carga puede registrar una eliminación y retornar sin guardar (`:193–200`).
- `clear` durante una carga retorna si la lista visible aún está vacía (`:216`), aunque el archivo contenga entradas.

Se ejecutaron tres pruebas con **el adaptador de archivos real**, un directorio temporal y una barrera únicamente para demorar la entrega del snapshot leído. Se partió del historial persistido `['older query', 'coach']`, se mutó durante la carga, se completó la carga y se creó una nueva instancia para simular reinicio.

| Operación durante carga | Estado en memoria, correcto | Estado tras reinicio, observado |
| --- | --- | --- |
| Recordar `new query` | `['new query', 'older query', 'coach']` | `['new query']` |
| Olvidar `older query` | `['coach']` | `['older query', 'coach']` |
| Borrar historial | `[]` | `['older query', 'coach']` |

Las tres pruebas pasaron la comprobación del estado en memoria y fallaron al verificar el estado después del reinicio. No es una regresión del mutex entre cuentas: el problema está en qué estado se envía a persistencia y cuándo.

Corrección necesaria: coordinar hidratación, mutaciones y guardado del resultado final por scope. Persistir las eliminaciones/borrado aunque la lista visible inicialmente esté vacía. Guardar usando la identidad del scope que se hidrató, sin depender de `_scope` si el usuario cambió de cuenta durante la espera, y conservar el orden frente a mutaciones posteriores. Cubrir las tres operaciones combinadas con reinicio.

La evidencia ejecutable está en `reaudit2_history_durability_probes.dart.txt`. Copiar a un temporal `.dart` y ejecutar con `flutter test --no-pub /ruta/al/temporal.dart` desde el proyecto.

## Cierres confirmados

| Punto | Resultado |
| --- | --- |
| R1: restauración tardía sobrescribe búsquedas | Reproducción original corregida; cierre parcial por el hallazgo de persistencia anterior. |
| R2: escrituras simultáneas entre cuentas | Cerrado para el escenario auditado. Mutex del ciclo lectura/modificación/escritura y reemplazo por archivo temporal presentes; probe original pasa. |
| R3: fallos de layout y contrato de encabezado en A | Cerrado para la suite actual. Caption compacto en 88; precios sin salto interno; padding del banner reducido; test comprueba conservar búsqueda y ocultar hero. La suite A–D pasa. |
| R4: formato | Cerrado. 57 archivos revisados, cero cambios requeridos. |

El reemplazo atómico se aplica en el camino de rename; el fallback de escritura directa declara expresamente que pierde atomicidad. No se certificó ese fallback en una plataforma no POSIX ni concurrencia entre isolates.

## Verificación ejecutada

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub test/features/welcome test/features/onboarding test/features/home test/features/catalog test/features/product test/features/checkout test/features/redesign_audit_p1_p2_test.dart --reporter expanded`: **168 aprobadas, 4 omitidas, 0 fallidas**.
- Archivo original `reaudit_history_probes.dart.txt`, copiado sin cambios a un temporal: **2 aprobadas**.
- Tres probes adicionales de hidratación más reinicio: **3 fallidas**, por el único hallazgo pendiente descrito arriba.
- `dart format --output=none --set-exit-if-changed` en las carpetas de implementación A–D y pruebas revisadas: **57 archivos, 0 cambios**.

Toolchain: `/Users/alexis/develop/flutter/bin/flutter` y Dart asociado.

Esta revisión cierra los fallos de layout reproducidos en tests; no sustituye aceptación visual con fuentes, imágenes definitivas y dispositivos reales. E/F, correlación autoritativa del pedido y Rewards transversal conservan su estado anterior; no forman parte de estos cuatro cierres.
