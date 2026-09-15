# Tercera reauditoría: durabilidad y orden de escrituras

## Cierre tras corrección solicitada

El P2 descrito abajo quedó corregido: `save` captura el snapshot y reserva su posición en la cola sin esperar la resolución de ruta. Las resoluciones se inician de inmediato para permitir concurrencia; sus errores se manejan aunque el guardado siga en espera. El mutex conserva el orden de invocación durante el ciclo de escritura.

La reproducción del listener se incorporó a `test/features/catalog/search_history_test.dart`, junto con pruebas de recuperación tras fallo de ruta y captura del snapshot antes de la espera. Verificación posterior: **19 pruebas del historial aprobadas; suite A–D con 175 aprobadas, 4 omitidas y 0 fallidas; análisis limpio y formato limpio en los archivos modificados**. El contenido siguiente conserva el hallazgo histórico y su reproducción.

## Resultado

La pérdida de persistencia descrita en `REAUDITORIA_2_2026-09-14.md` queda corregida en sus tres reproducciones. Se confirma el guardado del resultado combinado bajo `next`, antes de notificar listeners. Sin embargo, queda un P2 en el orden de escrituras del adaptador: invocar `save` antes de notificar no garantiza que esa escritura entre primero al mutex.

## P2 pendiente — Una escritura anterior puede sobrescribir una mutación posterior

Ubicación: `lib/features/catalog/search_history_persistence.dart:88`.

`save` ejecuta `await _file()` antes de reservar su lugar en `_serialized`. El mutex ordena según finalización de la resolución de ruta, no necesariamente según invocación de `save`. Si la resolución de la escritura antigua tarda más, una mutación posterior puede guardarse primero y después ser reemplazada por el snapshot antiguo.

Reproducción ejecutada con `SearchHistory`, el adaptador real y un proveedor de directorio controlado:

1. Iniciar carga de la cuenta `a` y recordar `new query` durante la espera.
2. Completar la carga con `older query`; se genera el guardado del resultado combinado.
3. Demorar únicamente la resolución de ruta de ese guardado.
4. Un listener agrega `listener query`; su guardado puede resolver la ruta y escribir antes.
5. Liberar el guardado anterior y esperar ambas operaciones.
6. Verificar memoria y reiniciar con una nueva instancia sobre el mismo archivo.

Resultado: memoria contiene `['listener query', 'new query', 'older query']`, pero tras reiniciar se obtiene `['new query', 'older query']`. Se pierde la mutación posterior.

El probe controla el orden asíncrono; no demuestra frecuencia del problema con el proveedor nativo en producción. Sí demuestra que el adaptador no satisface la garantía declarada de que las mutaciones posteriores siempre ganan.

Corrección requerida: reservar el orden lógico de los guardados antes del primer `await`, capturar el snapshot al invocar y conservar ese orden hasta escribir. La resolución de rutas puede iniciarse sin bloquear el inicio de otras llamadas; no debe decidir el orden final. Alternativamente, usar versiones por scope para rechazar snapshots obsoletos. Mantener el test de dos scopes concurrentes al ajustar la cola.

La prueba nueva de cambio de cuenta del repositorio usa una restauración de `a` sin mutaciones en `a` durante la espera; por tanto no entra al guardado combinado. Su mutación posterior ocurre después de esperar la carga. No cubre el intercalado del listener reproducido aquí.

## Verificaciones

| Comprobación | Resultado reproducido |
| --- | --- |
| `flutter analyze --no-pub` | Sin incidencias |
| Suite completa A–D y `redesign_audit_p1_p2_test.dart` | 172 aprobadas, 4 omitidas, 0 fallidas |
| Tres probes anteriores de durabilidad, copiados sin cambios | 3 aprobadas |
| Formato del alcance de 57 archivos | 0 cambios requeridos |
| Probe adicional de orden de guardado desde listener | Falla al comprobar reinicio; estado en memoria correcto |

Suite ejecutada: `flutter test --no-pub test/features/welcome test/features/onboarding test/features/home test/features/catalog test/features/product test/features/checkout test/features/redesign_audit_p1_p2_test.dart --reporter expanded`.

Toolchain: `/Users/alexis/develop/flutter/bin/flutter` y Dart asociado. Evidencia reproducible: `reaudit3_history_ordering_probe.dart.txt`; copiar a un temporal `.dart` y ejecutar con `flutter test --no-pub /ruta/al/temporal.dart` desde el repositorio. El probe libera la ruta tras una espera acotada si el guardado posterior está correctamente encolado, para no exigir que la implementación correcta escriba fuera de orden.

Los cierres de compilación, layout y formato siguen vigentes. Esta comprobación no amplía la aceptación a tipografías, imágenes definitivas, E/F ni Rewards. No se modificó código de implementación ni tests del proyecto; se añadieron únicamente informe y evidencia textual.
