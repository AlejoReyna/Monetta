# Huecos · spec contra el código y las capturas

Base: `feat/iphone-duo` en `738a61f`. Spec: `DESIGN_SPEC.md`. Capturas: solo las de `captures/captures.json`, etiqueta **simulator**. Donde no hay captura ni código, la celda dice **pending simulator capture** o ❓. Nada está verificado en hardware.

Lectura de las PNG el 28 oct 2026. No son una prueba de accesibilidad.

## Cómo se lee

| Marca | Significado |
|---|---|
| ✅ | La captura **simulator** muestra la regla y el código la sostiene, en texto por defecto. |
| ⚠ | Hay código o una captura, y falta un trozo de la spec. |
| ❌ | El código de esta rama no hace lo que la spec pide. |
| pending simulator capture | No hay imagen de esa celda. El juicio visual espera al Mac. |
| ❓ | Hace falta hardware (alcance, VoiceOver, hoja nativa, memoria). |

## Verificación pedida sobre el logo

La lectura de que el corte 30/132 estaba mal se retira. El bloqueo de «Comenzar» se mantiene.

1. **El corte 30/132 de la M está confirmado.** `lib/app/startup_reveal.dart:96-98` usa `widthFactor` 30/132 y el comentario dice que esos primeros 30 px son la M. Spec corregida 28-oct-2026, re-medida del Director (alfa > 20; md5 del 3x `0d0d3c93b5cffb27822aba476b9c8ca5`): 0-49 en 1x es M+O; la M termina en ~30. Cortes 3x: M 0–91 / O 92–153 / N 154–208 / E 209–262 / T 263–303 / T 304–330 / A 331–395. Cortes 1x, aproximados (~1/3): M 0–30 / O 31–50 / N 51–68 / E 69–86 / T 87–101 / T 102–110 / A 111–131. En 1x el asta de la M está a altura completa en las columnas 24–27 y la tinta baja a 3 px en la columna 30, antes de la O (pico en 33). En 3x el asta está en 73–82, con un valle de 5 px en 91. En la hoja de contacto solo se ve la M a los 220 ms y la O aparece hacia los 350 ms. Los cortes T/T/A caen en valles de tinta (303/304, 330/331); el travesaño de la segunda T aparece con la A. No es un hueco. Ningún ticket cambia el 30/132.
2. **`AbsorbPointer` impide «Comenzar» durante esa animación.** El absorbedor está en el velo a pantalla completa (`startup_reveal.dart:83-112`), no en el botón. El botón es `welcome_screen.dart:116-121` y no tiene `AbsorbPointer`. El velo tapa al hijo mientras la animación de 1100 ms no termina, y el hijo además está en `ExcludeFocus` (`startup_reveal.dart:66-72`). Ese hijo, cuando la app ya cargó, es el navigator cuyo home es `WelcomeGate` (`lib/main.dart:893-936`). Durante esos 1100 ms «Comenzar» no recibe el toque ni el foco. Esto sigue vigente.

`WelcomeScreen` no escribe el logo letra por letra. Funde el wordmark con `_Entrance` a 720 ms (`welcome_screen.dart:149-176`). No existe `logoWritten`. Eso es ❌ frente a la spec del Director y a la decisión del owner, no un fallo de la captura Duo: Welcome no se capturó.

## Tarea firma, por postura

| Postura | Estado | Evidencia |
|---|---|---|
| P1 | ⚠ | Capturas 01 y 02, **simulator**. Riel a la derecha, cuatro destinos. En 01 la etiqueta de estilo se lee «Crossbo...»: la spec pide el nombre entero. 02 es la ficha; no muestra el filtro de color ni la variante en una revisión de conjunto. El spike (`native-geometry-spike.log:9`) tiene oclusiones; la captura no las dibuja. Continuidad de ids: el drive lo afirma en código de test, no en una foto. |
| P2 | ⚠ | Capturas 07, 08, 08a, **simulator**. Carrito en 678 × 466 con riel **izquierdo** y una línea. El encabezado y la cantidad aguantan el texto grande (reporte y capturas). «Continuar al checkout» no aparece en el viewport reseñado de 07. Inicio y ficha en P2: pending simulator capture. La etapa `closed-again` dijo `barEdge` right para el mismo tamaño: el código sí lee el snapshot (`SceneDelegate.swift:94-97`, `adaptive_storefront_scaffold.dart:59-62`). |
| P3 | ⚠ | Capturas 03 y 04, **simulator**. Colección y ficha a la vez, riel derecho, nombre y precio en el detalle, tarjeta marcada. La acción primaria queda cortada al borde inferior de 03. El corte del código con división inactiva no usa la banda de x 455.5: usa el ratio ~0.42 (`browse_detail_layout.dart:207-224`). La spec pide usar la banda como guía si los mínimos caben. |
| P4 | ⚠ | Captura 06, **simulator**. Barras horizontales, columna, nombre, precio y «AGREGAR A BOLSA» visibles. La banda está inactiva: coincide con «no es un muro». No hay captura de Inicio, catálogo vacío ni carrito. `canSplit` es falso bajo 700 pt (`storefront_layout.dart:20-23`); 669 pt cae en una columna. Eso es coherente con el código, no un ✅ de toda la postura. |
| P5 | ⚠ | Captura 05, **simulator**. Foto a un lado, acciones al otro, riel al borde derecho. El test exige que la acción no cruce la región activa (`duo_shopping_task_test.dart:223-227`). La reseña visual de la PNG no encontró el título en el panel de la derecha; el código lo pinta encima del botón (`product_screen.dart:352-424`). Queda ⚠ hasta una segunda mirada a esa PNG, no ❌. No hay captura de catálogo+detalle en libro. |
| P6 | pending simulator capture | Apple la describe (`POSTURES.md`). El código parte en horizontal si el corte activo cubre ~80 % del ancho (`product_adaptive_body.dart:54-64`) y, si no cabe, deja el flujo junto (`browse_detail_layout.dart:203-206`). Nadie ha visto esa región activa en este simulador. |
| P7 | pending simulator capture | Sin pose en el recorrido. Sin layout propio en la spec. ❓ en hardware para saber qué pantalla queda de frente. |
| P8 | pending simulator capture | El riel usa `barEdge` y no el ancho (`adaptive_storefront_scaffold.dart:39-42`). No hay ventana de Split View capturada. Slide Over: no aparece en las páginas de Apple consultadas ni en el simulador. |
| P9 | ❌ para un segundo lienzo, y así debe seguir | `UIApplicationSupportsMultipleScenes` es falso (`ios/Runner/Info.plist:57`). No hay accessory de cámara. La decisión de la spec es diferir. No es un hueco a implementar en este lanzamiento. |
| P10 | ⚠ | El drive conservó el `State` de la ficha en la secuencia de poses (`duo_shopping_task_test.dart:183-246`) y sumó una unidad (`:260-268`). Eso es **simulator**, una sesión, sin teclado, sin hoja de filtros, sin Shopify y sin OAuth. Las pruebas de widget cambian el tamaño, no la división (`duo_continuity_test.dart` citado por el tester; `duo_checkout_continuity_test.dart:122-142`). |

## Pantallas a medida

Welcome en P1, P3 y P4: ❌ de la escritura y del flag; pending simulator capture de la pantalla. «Comenzar» existe (`welcome_screen.dart:117-118`) y el velo de arranque lo tapa, como arriba.

| Pantalla | P1 | P2 | P3 | P4 | P5 | P6 | P7 | P8 | P10 |
|---|---|---|---|---|---|---|---|---|---|
| Welcome | ❌ + pending | pending | ❌ + pending | ❌ + pending | pending | pending | pending | pending | ❌ el salto al frame final no existe |
| Inicio | ⚠ captura 01 | pending | pending | pending | pending | pending | pending | pending | ⚠ sin prueba de ancla de scroll |
| Catálogo / colección / marca | ⚠ el drive entra a Crossbody; no hay foto del listado solo | pending | ⚠ captura 03 | pending | pending | pending | pending | pending | ⚠ el test restaura el state, no hay foto del ancla |
| Búsqueda | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| Producto | ⚠ captura 02 | pending | ⚠ capturas 03 y 04 | ⚠ captura 06 | ⚠ captura 05 | pending | pending | pending | ⚠ drive, sin hoja ni teclado |
| Filtros | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| Vista rápida | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| Guardados | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| Carrito | pending | ⚠ capturas 07, 08, 08a | pending | pending | pending | pending | pending | pending | ⚠ una línea en el drive; el doble toque de continuar no está probado |
| Checkout | pending. **Pendiente de revisión del tester de pagos** | igual | igual | igual | igual | igual | igual | igual | ⚠ prueba de widget con launcher falso y solo cambio de tamaño. No es pago listo |
| Cuenta | pending | pending | pending | pending | pending | pending | pending | pending | ⚠ `login()` no se llama desde el layout (`account_controller.dart:225-226`); no hay prueba de pliegue con la hoja abierta |
| Pedidos | pending | pending | pending | pending | pending | pending | pending | pending | pending |

P9, todas las celdas: no aplica un diseño. La decisión está en `POSTURES.md`. No es pending de una captura de tienda en dos pantallas.

Overlays. Texto grande del carrito en P2: ⚠, cubierto por 08 y 08a, no por el resto de pantallas. Bold Text, Increase Contrast, Reduce Transparency, modo oscuro, VoiceOver y teclado de hardware: pending simulator capture, y VoiceOver además ❓ en hardware. Reduce Motion del logo: ❌, la ruta animada nueva no existe y `inWidgetTest` fuerza `reduceMotion` (`motion.dart:29-36`), así que los tests de widget no verían la escritura aunque existiera.

## Código que sí cubre parte de la spec

- Snapshot, rechazo de secuencia vieja y regiones usables: `system_layout_context.dart:80-112` y `:157-158`.
- Riel en el borde reportado, un solo uso del inset: `adaptive_storefront_scaffold.dart:59-68`.
- Overflow de la barra horizontal en alto corto: `monetta_bottom_navigation.dart:193-218`.
- Grupos a los lados de un corte activo: `product_adaptive_body.dart:52-109`.
- Una mutación local en el drive: `duo_shopping_task_test.dart:260-268`.
- Borrador de contacto y un launcher falso sobreviven a un cambio de tamaño: `duo_checkout_continuity_test.dart:76-142`. Etiqueta de esa prueba: no es **simulator** de Duo; es un widget test de tamaño. El archivo no dice «synthetic» en el nombre de la prueba de checkout. La de pliegue en `duo_continuity_test.dart` sí está nombrada synthetic en el log (`resume-targeted-test.log`).

## Pagos (lectura estática, no runtime)

El tester marcó PASS de lectura en `738a61f` para el guard del coordinador, el agregado, OAuth, la cancelación y los guards del PR 28. Los huecos que pidió pasar al plan:

- No hay prueba sintética de división y `barEdge` con (a) agregado en vuelo, (b) sync antes de la hoja, (c) hoja abierta. Cada una debe afirmar 1 mutación, 1 hoja, 1 línea.
- No hay prueba de pliegue con login abierto que afirme una sola llamada a `login()`.
- `continueToCheckout` (`checkout_screen.dart:294-374`) no tiene bandera de vuelo. Ticket S3 propuesto, sin empezar hasta que Alexis lo apruebe.
- Impresiones: nadie emite `EventType.impression` hoy. Hueco solo si se añaden.

Esas celdas siguen **pendiente de revisión del tester de pagos** cuando las pruebas existan. Esta tabla no las da por verdes.

## Qué no es un hueco de esta entrega

P9 diferido, tienda sin modo propio, comparación, arrastrar, Pencil, AR y multiventana. Están fuera del lanzamiento a propósito.
