# Revisión del prototipo del 17 de octubre frente a la app móvil

**Fecha:** 18 de octubre de 2026, America/Monterrey.  
**Resultado:** la identidad de Monetta está bien trasladada; quedan **tres diferencias de fidelidad de severidad media** en la composición móvil. El prototipo pasa sus comprobaciones automáticas, pero la fidelidad visual completa sigue pendiente.

## Confirmación del encargo de ayer

El archivo original es [MONETTA_WEB_DESIGN_CLAUDE.md](../../prompts/MONETTA_WEB_DESIGN_CLAUDE.md). El sistema de archivos registra su creación y última modificación el **17/10/2026 a las 20:45:45**. El plan se creó a las 20:39:22; la guía para Claude, a las 20:45:45; el README del prototipo, a las 22:22:41; y el registro de entrega, a las 22:33:31. Este último identifica la iteración del 17 de octubre.

Son archivos sin seguimiento en Git en este checkout: la fecha se corroboró con sus metadatos locales y el registro de entrega, sin atribuirles un commit que no existe. Se conservó íntegro el prompt original. SHA-256: `0a7ac81dd3910114805770dab2ce130e7dab06cfc20d40fb32f692d79d3124ed`.

## H01 · Media · El encabezado móvil desplaza demasiado el catálogo

La app combina volver, el título de la colección y el acceso a filtros en una barra. En la web móvil se acumulan la barra con logo y menú, las migas de navegación, otro título, los atajos de estilo y una fila de filtros. Además, colección, búsqueda y bolsa pierden el acceso directo para volver que tienen en la app.

En **375 × 812**, la primera tarjeta de Bolsas empieza en **y = 88 px** en Flutter y en **y = 351,63 px** en la web. Descontando los **28 px** del aviso de prototipo, la diferencia es **235,63 px**. En **440 × 956** se repiten ambos valores. La tarjeta mide 181,5 px de ancho en Flutter y 161,5 px en la web a 375 px, por los márgenes adicionales de la cuadrícula. Son diferencias de composición, no errores de desbordamiento.

La búsqueda presenta el mismo patrón: la primera tarjeta empieza en y = 221,5 px en la app y en y = 372,42 px en la web a 375 px; descontado el aviso, son 122,92 px adicionales. Aquí los datos y textos del encabezado difieren, por lo que esa cifra describe el caso capturado y no constituye un límite universal.

**Ajuste propuesto:** para teléfonos, adoptar el encabezado interior de la app con volver, título y acciones pertinentes; compactar o trasladar los controles secundarios sin perder filtros, orden, URLs ni accesibilidad. Mantener la navegación más extensa en escritorio. Evaluar la primera fila con el mismo viewport y contenido; no resolverlo reduciendo los objetivos táctiles o escondiendo capacidades.

**Fuentes:** `lib/features/catalog/collection_screen.dart:340`, `lib/features/navigation/monetta_page_header.dart:37`, `design-prototype/src/components/shell.js:40`, `design-prototype/src/pages/listing.js:99`.  
**Evidencia:** [app a 375](mobile/coleccion_375x812.png), [web a 375](web/coleccion_375x812.jpg), [mediciones Flutter](mobile/coleccion_375x812.json), [mediciones web](web/metrics.json).

## H02 · Media · La ficha móvil cambia los accesos del encabezado

El encabezado actual de la app muestra **volver · buscar · logo · cuenta · bolsa**. La web muestra **volver · menú · logo · buscar · bolsa**. El menú ocupa la posición de búsqueda y el acceso a cuenta desaparece justo en la ficha, donde tampoco se muestra el dock de navegación. Para llegar a cuenta hay que abrir el menú.

**Ajuste propuesto:** conservar la distribución de cinco elementos de `product_header.dart` en teléfonos: volver y buscar a la izquierda, logo centrado, cuenta y bolsa a la derecha. La cuenta puede seguir abriendo la explicación del acceso alojado en Shopify; no requiere implementar autenticación. Mantener la navegación de escritorio.

**Fuentes:** `lib/features/product/product_header.dart:12`, `lib/features/product/product_screen.dart:265`, `design-prototype/src/components/shell.js:42`.  
**Evidencia:** [app actual](mobile/ficha_375x812.png), [web actual](web/ficha_375x812.jpg), controles visibles registrados en [metrics.json](web/metrics.json).

La imagen maestra antigua `test/goldens/ui04/ficha_440x956.png` todavía muestra un encabezado con el nombre del producto. Esta auditoría generó capturas nuevas del código actual en una carpeta separada; el encabezado antiguo no se usó como especificación vigente.

## H03 · Media · Las recomendaciones de la ficha heredan el estilo de Inicio

En la app, “Más de Michael Kors” usa **Inter 17 / 600**. En la web usa **Playfair Display 24 / 400** en teléfono, porque `sectionHeader()` aplica el mismo rol editorial a todas las secciones. “Vistas hace un momento” utiliza el mismo componente y presenta la misma diferencia según el código.

También cambia la densidad: las recomendaciones de la app usan tarjetas de **52 % del ancho del teléfono**, foto **4:5** y nombre de **dos líneas**. La web reutiliza la tarjeta compacta de Inicio: **36 %**, foto **cuadrada** y nombre de **una línea**. A 375 px son aproximadamente **195 px frente a 135 px**. Se altera a la vez la jerarquía del encabezado y el tamaño de las piezas.

**Ajuste propuesto:** crear un rol de encabezado para las secciones de producto y una variante de carrusel que reproduzca esa anatomía móvil. Conservar Playfair y la tarjeta compacta donde sí corresponden, como Novedades en Inicio. Definir por separado las dimensiones de escritorio.

**Fuentes:** `lib/features/product/product_screen.dart:422`, `lib/features/product/product_screen.dart:990`, `lib/features/boutique/boutique_tokens.dart:128`, `design-prototype/src/pages/product.js:211`, `design-prototype/src/components/ui.js:62`.  
**Evidencia:** [recomendaciones en la app](mobile/ficha_recomendaciones_375x812.png), [recomendaciones en la web](web/ficha_recomendaciones_375x812.jpg), [rol medido en Flutter](mobile/ficha_375x812.json), [rol calculado en web](web/metrics.json).

## Coincidencias y adaptaciones justificadas

| Elemento | Resultado de la revisión |
| --- | --- |
| Logo y fotografías editoriales | Logo, portada, tote de estilos y foto de historia son copias idénticas de los archivos de la app, comprobadas con SHA-256. |
| Fuentes y paleta | Inter y Playfair cargan realmente en el navegador; blanco, tinta, grises y dorados coinciden con la capa boutique. |
| Inicio móvil | Mantiene fotografía con el mismo punto focal, buscador inferior, encabezados Playfair, carrusel compacto y orden de secciones. La primera tarjeta de Novedades empieza en y = 396,1 en Flutter y en y = 396,59 en web después de descontar el aviso, a 375 px. |
| Tarjetas | Coinciden marca/nombre/precio en Inter, radios de 12/8 px, corazón, acción circular y fotografía completa. Las reservas de altura y los productos del snapshot difieren; no se exigió igualdad de píxeles entre contenido distinto. |
| Navegación inferior | Dock blanco con selección dorada y las mismas cuatro entradas. En ficha lo sustituye la compra; en bolsa web se prioriza el checkout. |
| Galería y compra | Galería 4:5, miniaturas, favoritos/compartir, nombre Inter 24 y botón negro fijo conservan la identidad móvil. |
| Tablet y escritorio | Foto y texto en paneles, búsqueda superior, navegación de categorías, filtros laterales y ficha en dos columnas son adaptaciones explícitas del encargo original. |
| Comercio | Cantidad, precios comparativos reales y reseñas de muestra forman parte del alcance web. La ausencia del supuesto umbral de envío gratis está justificada en el plan; no se propone copiarlo de la app. |

## Verificación realizada en esta revisión

1. Lectura del prompt original, plan, componentes Flutter actuales, estilos y componentes del prototipo. Las afirmaciones anteriores de `STATUS.md` y `VERIFICATION.md` se trataron como antecedentes.
2. Build y ejecución de `npm run verify -- --out=../docs/web-redesign/audit-2026-10-18/evidence --port=4183` desde `design-prototype/`: **112/112 comprobaciones aprobadas, 129 s**, Node 24.21.0 y Brave/Chromium 155 ya instalado. Incluye siete anchuras, recorridos, tipografías y accesibilidad. [Reporte completo](evidence/verify-report.json).
3. Captura del **código Flutter actual** mediante una copia aislada del harness UI-04: seis pantallas a 375 × 812 y 440 × 956, más dos estados de recomendaciones; **14 PNG** y mediciones. Comando desde la raíz: `/Users/alexis_reyna/fvm/versions/3.44.8/bin/flutter test --no-pub --update-goldens --tags golden docs/web-redesign/audit-2026-10-18/mobile_reference_test.dart --reporter expanded`. Las doce ejecuciones terminaron sin excepciones de layout. `--update-goldens` escribió exclusivamente las referencias de esta auditoría: **no significa que se hayan aprobado los golden masters**. El harness de Cuenta emitió su aviso de depuración de múltiples instancias Drift.
4. Captura independiente de la web a **375, 440, 768 y 1440 px** para Inicio, colección, producto, búsqueda y bolsa; dos detalles de recomendaciones y un Inicio completo: **23 JPEG**. Comando: `node docs/web-redesign/audit-2026-10-18/capture-web.mjs`. Cero errores de página, consola o carga en esas visitas. [Métricas](web/metrics.json).
5. Inspección visual de las capturas móviles actuales, los detalles de recomendaciones y las adaptaciones representativas de tablet/escritorio. [Comparador local de pantallas](comparacion.html).

Los checks existentes comprueban consistencia con los valores definidos por la web; no contrastan todos los roles y posiciones con Flutter. Por eso 112/112 aprobadas puede coexistir con H01–H03 pendientes.

## Alcance y siguiente paso

Esta revisión produjo evidencia y hallazgos; el código del prototipo conserva el estado entregado el 17 de octubre. El [prompt de seguimiento para Claude](../../prompts/MONETTA_WEB_MOBILE_FIDELITY_REVIEW_CLAUDE_2026-10-18.md) concreta la revisión y los ajustes sobre ese mismo prototipo.

Las capturas Flutter son renderizados de widgets, con las fuentes reales y productos del bundle local. Las fotos de producto de red permanecen como placeholders por las condiciones del harness; esas zonas no se calificaron como fallos de diseño. Web usa el snapshot del 17 de octubre. No se hizo una comparación automática píxel a píxel entre motores ni se verificó la app en un dispositivo físico. La vista autenticada de Cuenta se capturó como referencia adicional; la cuenta web sigue siendo una entrada a Shopify, conforme al alcance original.
