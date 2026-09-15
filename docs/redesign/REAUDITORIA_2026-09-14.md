# Reauditoría de correcciones A–D

Fecha: 14 de septiembre de 2026. Revisión del árbol local actual, incluidos archivos sin commit. Complementa y actualiza el estado de `AUDITORIA_PAQUETES_A_D_2026-09-14.md`; los hallazgos cerrados aquí no deben seguir contándose como abiertos.

## Veredicto

Los dos P1 anteriores están corregidos. También están implementadas las conexiones de quick view, el paso de variante, el destino de cuenta para «Ver pedido» y la política de entrega sin fechas calculadas. La persistencia secuencial funciona, pero no puede darse por cerrada: se reprodujeron dos pérdidas de historial al coincidir operaciones asíncronas.

A continúa sin pasar su suite. B/C/D superan la suite indicada por el autor de la corrección. Esto no equivale a aprobación visual ni a una validación end-to-end con Shopify.

## Hallazgos abiertos, ordenados por impacto

### R1 — P2: la restauración sobrescribe una búsqueda recién enviada

Ubicación: `lib/features/catalog/search_history.dart:85`.

`setScope` espera a `load` y después asigna incondicionalmente la lista restaurada. Durante esa espera, `remember` puede crear y actualizar la lista del mismo scope. Cuando termina `load`, reemplaza esa actualización por datos antiguos. La pantalla llama a `setScope` y `remember` sin esperar su finalización (`search_screen.dart:106` y `:228`), por lo que el intercalado es posible.

Reproducción con almacenamiento de carga controlada: iniciar `setScope('account-a')`, recordar `new query`, resolver la carga con `older query`. Resultado observado: el historial termina como `['older query']`; la nueva consulta desaparece.

Corrección requerida: coordinar la hidratación y las mutaciones por scope. Evitar que una carga atrasada reemplace cambios nuevos, incluidas eliminaciones. Añadir prueba de búsqueda durante la carga.

### R2 — P2: escrituras concurrentes pueden perder el historial de otra cuenta

Ubicación: `lib/features/catalog/search_history_persistence.dart:60`.

Cada `save` lee el JSON completo, modifica una entrada y reescribe todo el archivo. No hay serialización de esa operación. Dos guardados pueden leer el mismo estado y terminar sobrescribiéndose; separar por claves en el JSON no evita el problema.

Reproducción con el adaptador real y un directorio temporal: ejecutar concurrentemente `save('account-a', ['coach'])` y `save('account-b', ['guess'])`. Tras completar ambos, la carga de `account-a` devolvió `[]`. La prueba falla; no se trata únicamente de una posibilidad inferida.

Corrección requerida: serializar el ciclo completo de lectura/modificación/escritura, preservar snapshots y usar reemplazo atómico del archivo para que una lectura no vea contenido incompleto. Una alternativa es almacenamiento transaccional. Mantener prueba de guardados coincidentes y separación de cuentas.

### R3 — P2: aceptación de A bloqueada por layout

La suite de welcome/onboarding/Home terminó con **36 aprobadas y 25 fallidas**. Se observaron desbordamientos de 5 px en el banner (`home_boutique_sections.dart:149`) y de 25 px en tarjetas (`product_tile.dart:233`) dentro de carruseles Home. Los tests de welcome también montan Home; su fallo no prueba por sí solo que la pantalla de bienvenida sea el origen.

El carrusel usa `captionHeight` de la densidad compacta (`home_boutique_sections.dart:254`); esta continúa en 74, mientras el ajuste a 112 se hizo para grid. Hay que cerrar el contrato de tamaño de A/B con contenido real y escalado de texto. No basta con aprobar las rejillas de catálogo.

No todos los 25 fallos son exclusivamente overflow: el test `owner storefront settings are reflected in the app home` espera que desaparezca `home-discovery-header`, pero la implementación conserva ese contenedor con búsqueda y oculta solo el hero. Revisar ese contrato antes de decidir si cambia el código o la expectativa.

Se confirma el estado fallido actual. No se certifica la afirmación «ninguno de mis cambios los causa»: faltó una versión base reproducible de antes de estas correcciones. La auditoría anterior quedó bloqueada al compilar y no estableció ese baseline.

### R4 — P3: el formato no está completamente limpio

La comprobación sin escritura devolvió código 1: de 49 archivos revisados, dos requieren formato:

- `test/features/catalog/collection_screen_test.dart`
- `test/features/product/product_package_c_captures_test.dart`

No es un bloqueo funcional, pero contradice la afirmación de formato limpio para este alcance.

## Hallazgos anteriores corregidos y límites

| Punto anterior | Resultado actual |
| --- | --- |
| Constructor `BoutiqueButton` incompatible | Cerrado. El constructor por defecto acepta `onPhoto`; análisis limpio. |
| Número de pedido anterior en confirmación | Cerrado como mitigación. La llamada usa `orderLabel: null`; ya no recorre el historial. La correlación autoritativa sigue pendiente. |
| «Ver pedido» vuelve al inicio | Corregido para el flujo base: se suministra callback que abre AccountScreen con Mis pedidos al estar autenticado; invitados reciben explicación. No abre el detalle de un pedido identificado. |
| Fechas calculadas como días naturales | Cerrado. Devuelve política de 3 a 5 días hábiles y explica que la fecha exacta se confirma con el envío. |
| Quick view sin conexiones | Cerrado por inspección: callbacks reales en colección, marca, búsqueda, Home, carruseles de producto y recomendaciones de bolsa; acción con tooltip/semántica. |
| Variante perdida al abrir ficha | Corregido por inspección del recorrido `quick_view → openProduct → ProductScreen`: se propaga `initialVariantIndex`. |
| Historial solo en memoria | Adaptador e inyección implementados; reinicio secuencial cubierto. Cierre condicionado a R1/R2. |

La prueba nueva de «Ver pedido» comprueba un callback artificial, no el recorrido completo checkout → cuenta autenticada/invitado. La prueba nueva de quick view comprueba el botón de una tarjeta aislada. La conexión real y el paso de variante se verificaron por lectura del código; no se presenta esa lectura como una prueba end-to-end ejecutada.

La confirmación con `orderLabel: null` no se actualiza automáticamente cuando aparece el pedido en el historial. Se acepta como estado sin identidad, no como implementación final de correlación.

## Ejecución reproducida

Toolchain: `/Users/alexis/develop/flutter/bin/flutter` y su Dart asociado.

| Verificación | Resultado |
| --- | --- |
| `flutter analyze --no-pub` | Sin incidencias. |
| `flutter test --no-pub test/features/catalog test/features/product test/features/checkout test/features/redesign_audit_p1_p2_test.dart --reporter expanded` | 103 aprobadas, 4 omitidas, 0 fallidas. Incluye las seis pruebas nuevas. |
| `flutter test --no-pub test/features/welcome test/features/onboarding test/features/home --reporter expanded` | 36 aprobadas, 25 fallidas. |
| Dos pruebas adicionales de concurrencia del historial | Ambas fallaron y reprodujeron R1/R2. |
| `dart format --output=none --set-exit-if-changed` sobre carpetas de diseño revisadas y tests correspondientes | 49 archivos revisados; 2 requieren formato. No se escribió formato. |

El código de las dos pruebas adicionales se conserva como evidencia en `reaudit_history_probes.dart.txt`. Para ejecutarlas, copiar ese archivo a un temporal con extensión `.dart` y ejecutar `flutter test --no-pub /ruta/al/temporal.dart` desde el proyecto.

## Pendientes que esta corrección no cierra

Fuentes registradas, imágenes definitivas, capturas legibles comparadas con la referencia, navegación compartida y contenido editorial de marca siguen pendientes. E y F continúan fuera de esta corrección; Rewards monetario conserva el alcance transversal de `docs/MONETTA_REWARDS_V1_PLAN.md`.

Siguiente cierre: R1/R2 en B; layout y expectativas de A; formato de los dos tests; pruebas de recorrido real para checkout y quick view. Después, aceptación visual de A–D y desarrollo pendiente de E/F.

No se modificó código de implementación ni los tests del proyecto durante esta reauditoría. Solo se añadieron este informe y evidencia textual; los probes se ejecutaron desde un archivo temporal.
