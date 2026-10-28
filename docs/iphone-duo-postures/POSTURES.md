# Posturas de iPhone Duo para Monetta

Estado: inventario para diseño. Cada fila tiene fuente o queda marcada como no verificada.

Nada en este documento está verificado en hardware. Los números de puntos lógicos son observaciones del simulador **Monetta Duo Implementation** (iOS 27.1, Xcode 27.1), no constantes de layout. El inset de 84 pt y la banda de 40 pt se citan como mediciones; el código no debe copiarlos. La postura se lee del snapshot (`SystemLayoutContext`), nunca del ancho solo.

Etiquetas: **simulator** = corrida ya registrada en el repo. **concept** = dibujo de este paquete. No hay capturas nuevas: esta sesión no puede arrancar el simulador de Duo.

## Fuentes consultadas

Apple, leídas el 28 de octubre de 2026:

- [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) (markdown público en `developer.apple.com/tutorials/data/design/human-interface-guidelines/designing-for-iphone-duo.md`). En adelante, HIG.
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo).
- [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/), tech talk 111462.
- [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/), tech talk 111463.
- [Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/), tech talk 111464. El brief pide 111462 y 111463; 111464 es la fuente de las dos pantallas a la vez y no se usa para inventar una pose.
- [Get ready for iPhone Duo](https://developer.apple.com/iphone-duo/).
- Símbolos ya archivados en el repo: `artifacts/iphone-duo/apple-reserved-regions.md`, `artifacts/iphone-duo/apple-bar-edge.md`.

Evidencia del repo, etiqueta **simulator**:

- `artifacts/iphone-duo/resume-runtime-summary.json` (geometría por etapa y nueve capturas con SHA-256).
- `artifacts/iphone-duo/runtime-captures/*-fixture-photos.png`.
- `artifacts/iphone-duo/native-geometry-spike.log` línea 9 (oclusiones del exterior vertical). El JSON de compras no repite las oclusiones: el driver no las imprime (`integration_test/duo_shopping_task_test.dart:92-105`).
- `docs/IPHONE_DUO_IMPLEMENTATION_REPORT.md`.

El plan anterior (`docs/IPHONE_DUO_DESIGN_AND_LAUNCH_PLAN.md`) describe la intención de producto. No es una medición de Apple.

## Decisiones P6 y P9

### P6, sentado / tabletop — provisional

Apple describe la pose. El simulador de Monetta todavía no la produjo.

- HIG, «Device poses»: la gente dobla el aparato «partially folded like a book, placed down on a surface, or standing on its edges».
- Tech talk 111463, minuto 4:00: «When the device is propped up on a table, the two regions support different kinds of experiences. The top region works well for content that benefits from visibility at a distance.» El resumen de esa sección añade que la región de abajo conviene a los controles.
- «Preparing your app»: con el aparato parcialmente abierto, un overlay arrangement pone la vista primaria en la parte trailing o inferior respecto al pliegue, y la secundaria en la parte leading o superior.
- HIG, «Arrangement views»: un split arrangement parte en horizontal si el área es más ancha que alta, y en vertical si es más alta que ancha.

En el simulador, la etapa `inner-portrait` mide 669 × 951, `barEdge: none`, banda horizontal `y 455.5`, alto 40, **inactiva** (`resume-runtime-summary.json`). La etapa `partial-fold` es la misma ventana apaisada que `open-landscape` (951 × 669) con esa banda **vertical y activa**. No hay captura con una división horizontal activa. El tablero anterior dibuja un «seated»; eso es **concept**, no evidencia.

**Decisión provisional.** No se retira el layout sentado. Tampoco se da por existente en el simulador. Si el host reporta una división **activa** cuya intersección cubre al menos cuatro quintos del ancho del contenido, la galería y el contenido van en la región de arriba y los controles de compra en la de abajo, usando el rectángulo reportado. Si las dos regiones no caben (`regionMinimumWidth` 240 y `minimumTaskHeight` 200 en `lib/app/storefront_layout.dart:14-15`), se cae al flujo de una columna que el código ya tiene (`lib/features/product/product_adaptive_body.dart:79-109`). No hay un modo llamado «sentado» ni un ángulo de bisagra.

**Comprobación que falta, en el Mac.** Simulador `Monetta Duo Implementation`, UUID `A38CDB10-3E59-4575-A58C-4E1072B8A4CC`. Llegar a la pose que el test llama `inner-portrait` (`integration_test/duo_shopping_task_test.dart:233-238`: alto mayor que ancho, divisiones no vacías, `barEdge == none`). Sin rotar a apaisado, aplicar en Device Hub el mismo pliegue parcial que activó la banda vertical en `partial-fold`. Leer el siguiente `DUO_GEOMETRY`.

- Si hay una división `active: true`, el ancho del frame es al menos 0,8 del ancho de la ventana, la ventana sigue siendo más alta que ancha, y se anota el `barEdge` que el host mande: P6 existe en ese simulador y la spec de abajo queda confirmada para el simulador.
- Si Device Hub no ofrece la pose, si la ventana pasa a 951 × 669, o si la banda horizontal sigue inactiva: anotarlo. La spec de «división horizontal activa» se conserva porque Apple describe la pose, y el panel sentado del tablero sigue siendo **concept**. No se inventa un hueco de bisagra.

Hasta ese resultado, P6 es **provisional**.

### P9, las dos pantallas a la vez — diferido, fuera del lanzamiento

No es «el sistema no puede». Apple documenta un camino concreto, y este lanzamiento no lo usa.

- Tech talk 111464: los scene accessories pueden mostrar contenido en más de una pantalla. El ejemplo nuevo es `CameraCaptureAccessory`: UI suplementaria en la pantalla exterior mientras la UI principal sigue en la interior, solo con la app a pantalla completa en la interior y una sesión de cámara activa. Al cerrar el aparato, el accessory deja de estar disponible.
- El mismo video: las ventanas nuevas no se crean en la pantalla exterior; eso queda para la interior. Todas las apps participan en Split View de dos apps, lado a lado.
- Monetta no es una app de cámara. `UIApplicationSupportsMultipleScenes` está en `false` (`ios/Runner/Info.plist:57`). El plan de lanzamiento excluye «two simultaneously active displays» (`docs/IPHONE_DUO_DESIGN_AND_LAUNCH_PLAN.md:257`).
- El recorrido del simulador usa una ventana cada vez (exterior o interior), nunca las dos.

**Decisión.** P9 no entra al lanzamiento. No hay un segundo «Comenzar», ni un segundo carrito, ni un checkout en la otra pantalla. La tarea de compra vive en la única escena que el host presenta. Un accessory de cámara queda fuera de alcance hasta que el owner lo pida. No se afirma que iOS impida toda UI simultánea; se afirma que Monetta no la diseña para esta entrega.

## Inventario

| ID | Postura | ¿En Duo? | Geometría observada (simulator) | Barra | División | Decisión de diseño |
|---|---|---|---|---|---|---|
| P1 | Cerrado, exterior, vertical | Sí. HIG: exterior cerrado, barras al lado. | 466 × 678. Insets 0, 0, 84, 34. Capturas 01 y 02. | `right` | Ninguna | Experiencia compacta. Riel en el borde reportado. |
| P2 | Cerrado, exterior, horizontal | Sí. El plan de Apple pide rotar cada pose. 111462: en exterior horizontal el overflow es más frecuente. | 678 × 466, sin divisiones. Etapa `closed-again`: `barEdge` **right**. Capturas 07, 08 y 08a: `barEdge` **left**, insets 84, 0, 0, 34. | El del snapshot | Ninguna | Alto corto. Seguir el borde reportado; no fijar «siempre a la derecha». |
| P3 | Abierto plano, interior horizontal | Sí. HIG: en interior horizontal las barras siguen al lado. | 951 × 669. Insets 0, 0, 84, 34. Capturas 03 y 04. | `right` | Vertical x 455.5, ancho 40, alto 669, **inactiva** | Dos paneles. La banda inactiva es guía, no muro. |
| P4 | Abierto plano, interior vertical | Sí. HIG y 111462: en interior vertical vuelven las barras horizontales. | 669 × 951. Insets 0, 82, 0, 34. Captura 06. | `none` | Horizontal y 455.5, alto 40, ancho 669, **inactiva** | Una columna o paneles apilados. La banda inactiva no parte la página. |
| P5 | Plegado parcial, libro | Sí. HIG y 111463: el pliegue divide la pantalla interior. | 951 × 669, mismos insets que P3. Captura 05. | `right` | La misma banda vertical, **activa** | Cada panel entero en un lado. Ningún control cruza el pliegue. |
| P6 | Plegado parcial, sentado | Descrita por Apple (arriba). **No reproducida** en el simulador de Monetta. | Pendiente de la comprobación. | El que reporte el host | Horizontal activa, si el check la produce | Provisional: contenido arriba, controles abajo. |
| P7 | Tienda / de canto | HIG: «standing on its edges». 111466 (página de Apple, no transcrita aquí entera) dice «standing on its own, resting on its edges». Ninguna página consultada dice qué pantalla mira a la persona. | No capturado. | — | — | Sin layout propio. Sirve la postura cuya geometría coincida con el snapshot. |
| P8 | Ventana en la interior: Split View, extremos, Slide Over | Split View: sí. HIG: dos apps comparten la interior y cada una pone controles en su borde exterior; la app de la izquierda los lleva a la izquierda. 111464: todas las apps participan; también hay un layout de video apilado con apps, que se trata como la misma geometría de escena. Ventanas nuevas: solo en la interior. **Slide Over:** la frase no aparece en el HIG, ni en 111462, 111463, 111464, ni en «Preparing your app», leídos el 28 oct 2026. No se afirma que exista ni que no exista. | No capturado. | Puede ser left, right o none | La que reporte esa ventana | Nunca asumir «riel derecho en toda ventana ancha». |
| P9 | Las dos pantallas a la vez | Posible para un scene accessory de cámara (111464). No para el lanzamiento de la tienda. | El recorrido usa una ventana. | — | — | Diferido. Ver la decisión de arriba. |
| P10 | Transiciones | Sí. «Preparing your app»: al abrir, cerrar, plegar y rotar, el contenido pasa de una pantalla a otra. El sistema anima el cambio. | Una sesión montada sobrevivió exterior → interior horizontal → pliegue → plano → interior vertical → cerrado (`docs/IPHONE_DUO_IMPLEMENTATION_REPORT.md`). | Cambia con el snapshot | Pasa de inactiva a activa y de eje | El sistema anima el pliegue y la rotación. El estado de compra no se duplica. |

### Oclusión de cámara (simulator, no en el JSON de compras)

`artifacts/iphone-duo/native-geometry-spike.log:9`, exterior 466 × 678, `barEdge` right, sin divisiones, dos oclusiones activas:

- frame x 399.67, y 29.33, 37 × 37
- frame x 382, y 0, 84 × 170

HIG: la cámara exterior siempre está; la interior solo aparece cuando la cámara está activa. Esas dos regiones son la medición del spike, no un mapa para todas las posturas. Las capturas de Flutter no dibujan el recorte del sistema.

### Qué no se afirma

- No hay tamaño de hardware, ni densidad, ni ángulo de bisagra medido.
- Los pixeles de App Store del plan anterior (1398 × 2034 y el resto) se citan allí con fecha 27 oct 2026. Esta revisión no reabrió la página de screenshot specifications, así que no se vuelven a presentar como comprobados hoy.
- P6, P7, P8 y Slide Over no tienen captura.
- P2 muestra dos bordes de barra distintos en la misma medida de ventana. Los dos están en el JSON. No se elige uno.
