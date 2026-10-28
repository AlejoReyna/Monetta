# Spec de diseño · Monetta en cada postura de iPhone Duo

Estado: especificación. No es una captura, no está verificada en hardware, y no declara la app lista para el App Store ni para una insignia.

La geometría se lee del snapshot de `SystemLayoutContext` (`lib/platform/system_layout_context.dart`). Los puntos citados en `POSTURES.md` son observaciones **simulator**. No son umbrales. Los umbrales de presentación siguen en `lib/app/storefront_layout.dart` (hueco 24, split a 700 × 480, paneles mínimos 320 y 340, riel de respaldo 72, split de bolsa a 860, alto mínimo de tarea 200, región mínima 240, galería mínima 180). No se mueven a los tokens en esta entrega: son decisiones de la app, no de marca, y el reporte de implementación ya los dejó ahí a propósito.

## Marca

Tokens claros en `design-system/monetta.tokens.json`: marfil `#FBF8F2`, acción `#745237`, tinta `#211B16`, oro `#C5A052` solo decorativo. El plan de lanzamiento calcula oro/marfil en 2.32:1; el oro no lleva etiquetas. Playfair Display en títulos editoriales y nombres de pieza. Inter en controles, precios y navegación. Objetivo táctil mínimo 48 × 48, estándar de Monetta, no una cifra de Apple. Copia de interfaz en español de México.

El modo oscuro usa la paleta que ya existe (`MonettaColors.dark` y `darkRolesOnly` en los tokens). No se diseña una paleta nueva. No hay captura oscura.

## Regla de accesibilidad (todas las pantallas a medida)

Se aplica a Welcome, Inicio, Catálogo, colección, marca, Búsqueda, Producto, Filtros, Vista rápida, Guardados, Carrito, Entrega al checkout, Cuenta y Pedidos. No se repite celda por celda.

- Texto más grande del sistema: si `StorefrontLayout.canSplit` es falso o `enlargedText` es verdadero (`storefront_layout.dart:18-23`), una sola columna legible. Los nombres de pieza hacen wrap completo; no se eliden. El mínimo de 48 pt crece con el texto, como ya hace el riel con el contador.
- Bold Text: el peso no es el único signo de selección. El riel y la barra ya leen `boldTextOf` para la etiqueta (`monetta_bottom_navigation.dart:161-163`).
- Increase Contrast: texto en tinta sobre marfil, o blanco sobre `#745237`. El oro no es texto.
- Reduce Motion: `reduceMotion(context)` en `lib/app/motion.dart:32-37` (`disableAnimations` o `accessibleNavigation`). El logo queda completo. Los crossfades de 180 ms pasan a cambio instantáneo.
- Reduce Transparency: la barra usa el color opaco de navegación. No se añade blur.
- VoiceOver y teclado de hardware: «Comenzar», Atrás, Cerrar y la acción primaria tienen nombre accesible desde el primer frame. El orden es Atrás o Cerrar, acciones, luego los cuatro destinos. **No verificado** en hardware ni en el simulador de esta entrega.
- Nombres largos en español, vacío, error y sin red: el mensaje cabe en la región usable; la acción de recuperar queda fuera de divisiones y oclusiones activas. La copia vacía que ya existe no se reescribe aquí.

## Continuidad de pago y de bolsa

Revisión estática del tester de pagos, PASS de lectura de código sobre `738a61f`. No es una prueba de simulador ni de hardware. **Pendiente de revisión del tester de pagos** en cuanto a las pruebas nuevas y al guion de hardware. No se afirma que el pago esté listo.

Reglas de esta spec:

1. El estado de checkout y de bolsa vive solo en `ShopifyCheckoutCoordinator`, `CartController` y `CatalogStore`, por encima del layout. Un adaptador de postura no guarda ese estado y no llama a agregar, a `present` ni a `login` desde `build`, `LayoutBuilder`, `didUpdateWidget`, `didChangeDependencies` ni un callback de geometría.
2. Lo que cambia con la postura conserva tipo y key en el mismo slot, o usa `GlobalKey` / `KeyedSubtree` para el subárbol que tiene estado. `ProductAdaptiveBody` ya mueve galería y detalle con `KeyedSubtree` (`product_adaptive_body.dart:35-41`). `BrowseDetailLayout` mantiene `ProductScreen(key: ValueKey(id))` en el mismo `Stack` (`browse_detail_layout.dart:254-273`). `AdaptiveStorefrontScaffold` mantiene los mismos slots de `Stack` al pasar de barra a riel (`adaptive_storefront_scaffold.dart:52-101`).
3. Una línea de bolsa sigue siendo una línea. Un pliegue no suma otra unidad, no abre otra hoja de Shopify, no repite OAuth y no repite una impresión.
4. «Comenzar», agregar, pagar y entrar solo nacen de un toque. El pliegue no es un toque.

El guard de la hoja de Shopify está en el coordinador (`_presenting` / `_openingFallback`, `lib/app/shopify_checkout_coordinator.dart:52-53`). `login()` sale si no puede o si ya carga (`lib/app/account_controller.dart:225-226`). Agregar usa `_adding` en la ficha (`lib/features/product/product_screen.dart:80`, `196-202`). Eso es lectura de código, no una corrida.

Hueco aparte, no es de postura: `continueToCheckout` (`lib/features/checkout/checkout_screen.dart:294-374`) no tiene bandera de vuelo. Lo disparan los botones de la bolsa con la etiqueta «Continuar al checkout» (`checkout_screen.dart:452` y `:458`). Un doble toque puede empujar dos rutas `CheckoutFlowScreen`. Cada ruta aún necesita su propio pago, y el coordinador impide un `present` concurrente. El ticket S3 de abajo queda **propuesto y sin empezar** hasta que Alexis lo apruebe. No se confunde con «CONTINUAR AL PAGO SEGURO» (`checkout_screen.dart:1875`), que sí pasa por `_retryBlocked` (`checkout_screen.dart:744-745`).

## Crossfades

Pegado de la spec del Director de Movimiento (punto 7). Curva de la casa `Cubic(0.16, 1, 0.3, 1)` (`lib/app/motion.dart:16`). `kSnap` es 180 ms (`motion.dart:12`). Solo opacidad. El sistema anima el pliegue y la rotación. No se simula un pliegue.

| Dónde | ¿Crossfade? |
|---|---|
| Cambia el producto en el panel de detalle y la colección sigue montada (P3/P5) | Sí, 180 ms |
| El panel de detalle aparece o desaparece al cruzar el umbral de dos paneles por una acción de la persona (cerrar el detalle, por ejemplo) | Sí, 180 ms |
| Reflujo por plegar, desplegar, rotar o cambiar el tamaño | No |
| Cambia el eje o el borde de la barra | No |
| Galería y controles se reacomodan (`ProductAdaptiveBody`) | No |
| El texto grande obliga a una columna | No |
| Cambio de destino (Inicio, Catálogo, Carrito, Cuenta) | No |
| Logo de Welcome | No. Tiene la regla de abajo |

Con Reduce Motion el crossfade es instantáneo. El panel nuevo recibe toques desde el frame 0.

## Welcome · logo

El comportamiento del logo de Welcome lo revisa el Director de Movimiento. Esta sección pega su spec y la completa con el inventario de `POSTURES.md`. La evidencia de movimiento está en `docs/research/monetta-motion-evidence-2026-10-27/` del commit `fbeac82` (`LOGO_Y_ENTREGA.md`, `INVESTIGACION_V2.md`, `REFERENCIAS_COMERCIALES.md`). Ese commit no está en esta rama; se cita, no se copia el árbol.

### Decisión del owner

Alexis, 28 de octubre de 2026, comunicado por Daniel: el logo se anima **una sola vez por instalación**, en la primera bienvenida, y queda persistido en el aparato. No se repite al recargar, ni en un arranque en frío posterior, ni al plegar, rotar, cambiar el tamaño o volver al primer plano. **No es una pregunta abierta.**

El flag propuesto se llama `logoWritten`. No se reutiliza `app_preferences.onboarding_state`: ese contrato solo decide si la bienvenida se muestra (`lib/features/welcome/welcome_gate.dart:6-16`) y el propio archivo pide no mezclarlo con otro significado. Persistir el flag es un ítem de backlog; esta entrega no lo implementa.

### Spec del Director (pegada)

Variante A de `LOGO_Y_ENTREGA.md` @ `fbeac82`: se revela el PNG original con siete máscaras, M‑O‑N‑E‑T‑T‑A, en 1000 ms. Curva `kMotionCurve` dentro de cada letra, sin rebote. Los tiempos son parámetros de prueba propios (N6); ninguna fuente los prescribe. Ninguna de las ocho apps revisadas escribe el logo letra por letra (N1, `REFERENCIAS_COMERCIALES.md` @ `fbeac82`). FARFETCH y Moda Operandi lo muestran estático. Shop dibuja la «o» en ≈1,2 s con el botón visible antes de terminar (N1, citado según el registro; el Director no reabrió la hoja). La escritura es petición de marca, no una mejora de uso ni de conversión.

«Comenzar» funciona desde el primer frame. Al tocarlo, el logo salta al frame final y se navega. El control estático C sigue siendo obligatorio para comparar; esta spec define A.

Tiempos: M 0–220, O 220–350, N 350–480, E 480–610, T 610–740, T 740–870, A 870–1000. Cada letra se revela de izquierda a derecha en su caja. No hay cursor, destello, bucle, sonido, fundido por letra ni animación de salida. A los 1000 ms el bitmap es el PNG original.

La caja tiene su tamaño final desde el frame 0. Las letras no se recentran. `Semantics(label: 'Monetta')` desde el frame 0. Sin paquetes de animación. El controlador vive fuera del `State` de Welcome, en un `ValueNotifier` de app: `notStarted`, `playing`, `done`.

| Evento | Regla |
|---|---|
| Primera bienvenida y `logoWritten == false` | `playing`. Al terminar o cancelar, `done` y se persiste `logoWritten = true`. |
| Arranque en frío posterior, o Welcome otra vez | `done`. Logo estático. |
| Volver de segundo plano mientras `playing` | Salta al frame final. |
| Plegar o desplegar a mitad (P1↔P3/P4, P3↔P5) | Salta al frame final en el primer frame de la geometría nueva. |
| Rotar a mitad (P3↔P4, P1↔P2) | Salta al frame final. |
| Resize o Split View (P8) | Salta al final si estaba `playing`. `done` no vuelve a `playing`. |
| Snapshot nuevo sin cambio del `Size` de la caja (la división pasa de inactiva a activa y la caja no se mueve) | Termina normal, hasta 1000 ms. |
| Tocar «Comenzar», el logo o hacer scroll | Salta al final y la acción sigue. |
| Reduce Motion en caliente | Salta al final. |
| Desmontaje | Cancela el ticker, libera recursos y marca `done`. |

Qué cuenta como cambio de geometría: cambia el `Size` de la caja final, calculado desde el snapshot. No se infiere la postura por el ancho. Al cambiar de postura la caja nueva se adopta **sin interpolar**. El sistema ya anima la transición.

Reduce Motion (`disableAnimations` o `accessibleNavigation`): logo completo en el frame 0, una sola etiqueta «Monetta», estado `done`. Si el PNG falla, el `errorBuilder` de `MonettaWordmark` pinta «MONETTA» estático (`lib/app/theme.dart:547-554`) y no hay máscaras.

### Lo que el código hace hoy (verificado en esta revisión)

`StartupReveal` (`lib/app/startup_reveal.dart`) dura 1100 ms. Mientras no termina, un `AbsorbPointer` (`startup_reveal.dart:83`) cubre un velo a pantalla completa encima del hijo (`:74-112`). El hijo también está en `ExcludeFocus` y `ExcludeSemantics` hasta `isCompleted` (`:66-72`). El clip usa `widthFactor: 30 / 132 + …` y el comentario dice que los primeros 30 px de 132 son la M (`:96-98`). Solo mira `MediaQuery.disableAnimationsOf` (`:44`), no `reduceMotion`.

Cuando `ready` pasa a verdadero, el hijo de `StartupReveal` es el navigator, y el home es `WelcomeGate` → `WelcomeScreen` (`lib/main.dart:891-936`, `lib/features/welcome/welcome_gate.dart:142-146`). «Comenzar» está en `welcome_screen.dart:116-121`. El botón **no** tiene su propio `AbsorbPointer`. Durante los 1100 ms el velo de arriba se come los toques y el foco, así que «Comenzar» no se puede usar mientras `StartupReveal` anima. La afirmación del Director queda confirmada con esa precisión: el bloqueo es el overlay ancestro, no un absorbedor en el botón.

Medición propia del PNG, 28 oct 2026, alfa > 16, Pillow:

| Activo | Tamaño | Columnas de tinta, inclusive |
|---|---|---|
| `assets/images/logo_monetta.png` | 132 × 38 | 0–49 · 51–67 · 69–85 · 87–131 |
| `assets/images/3.0x/logo_monetta.png` | 396 × 113 | 0–147 · 154–201 · 209–256 · 263–395 |

La primera corrida de tinta del 1x termina en la columna 49, no en la 30. El 30/132 de `StartupReveal` no es el borde de la M. En 3x, E+T+T+A siguen en una sola corrida (263–395): sus cortes internos no están medidos. La gota cae dentro de la M (0–147 en 3x). `StartupReveal` no se reutiliza para la escritura. No se suma su espera de 1100 ms. Hay que quitar ese `AbsorbPointer` del camino de «Comenzar».

`WelcomeScreen._Entrance` (`welcome_screen.dart:139-177`) funde el wordmark y el titular en `kEnter` (720 ms) y no escribe letras. El botón queda fuera de ese fundido. No hay `logoWritten`.

### Caja y «Comenzar» por postura

La caja nace con su tamaño final para la postura en la que empieza. Posiciones desde el snapshot, no desde 466 ni 951. Altura del wordmark actual: `MonettaTokens.logoHeight * 2` (`welcome_screen.dart:77`) hasta que el Director fije otra. Recomendación de encaje, no una medida de Apple: en P1 el ancho de la caja no pasa del ancho usable; en P3 y P4 tampoco, y no cruza una división **activa**.

| Postura | Caja del logo | «Comenzar» |
|---|---|---|
| P1 | Centrada en el área usable: ventana menos insets del snapshot, fuera de la oclusión de cámara medida en el spike y fuera del riel. | Zona inferior del área usable, fuera de la oclusión y del riel. ≥ 48 × 48. Visible y activo en el frame 0. |
| P3 | La banda vertical inactiva es guía, no muro. Recomendación del Director (N6), adoptada aquí: centrar la caja en el lado que lleva el texto de bienvenida, sin cruzarla, para que P3→P5 no tenga que moverla. El tamaño fino sigue abierto para el Director; la regla de no cruzar la banda ya no. | Entero en un lado de la banda, aunque la banda esté inactiva, para no saltar de lugar si P5 llega enseguida. ≥ 48 × 48. Frame 0. |
| P4 | Centrada en horizontal, por encima de la banda horizontal inactiva. No la usa como muro. | Debajo del texto, fuera de la banda. Si la persona tiene que desplazar, el botón va fijo al borde inferior usable para seguir en el frame 0. |
| P2 | Hereda P1, en el área usable corta (alto observado 466). La caja no crece. | Fijo al borde inferior usable, fuera del riel, del lado que reporte el snapshot (en las capturas 07/08 ese lado fue el izquierdo; en la etapa `closed-again`, el derecho). Frame 0. |
| P5 | Si la bienvenida arranca aquí, ni la caja ni el botón cruzan la división activa. Caja en la región leading; no se anima un cambio de caja. | Entero en una región usable. Si no caben caja y botón en regiones distintas, los dos van a la región mayor, sin cruzar el corte. |
| P6 | Provisional, solo si el check de `POSTURES.md` reporta división horizontal activa. Caja entera en la región de arriba (contenido a distancia, 111463). | Entero en la región de abajo, fuera del corte. ≥ 48 × 48. Si las dos regiones no cumplen los mínimos de `storefront_layout.dart`, un solo flujo en la región mayor y el botón al final de ese flujo, todavía fuera del corte. |
| P7 | Sin pose propia. La caja de la postura cuyo snapshot coincida (P1/P2 si el host está en el exterior; P3–P6 si está en el interior). | El mismo «Comenzar» de esa postura. No hay una coordenada de tienda. |
| P8 | La caja se calcula con el snapshot **de esa ventana**. Si el `Size` de la caja cambia al redimensionar, se salta al frame final. | En el área usable de esa ventana, del lado contrario al `barEdge` reportado. En Split View la app izquierda puede traer el borde izquierdo (HIG). Nunca se asume el riel derecho. Fuera de divisiones y oclusiones activas de esa ventana. |
| P9 | No hay segunda caja. | No hay un segundo «Comenzar». El único botón vive en la única escena de compra. |
| P10 | La caja toma la geometría nueva sin interpolar. Si estaba `playing`, salta al final, salvo el caso de snapshot sin cambio de `Size` de la caja. | Sigue activo durante la transición. Se recoloca sin animación propia. No hay `AbsorbPointer` encima. |

Reduce Motion en todas: logo completo, botón activo, una etiqueta «Monetta».

### Onboarding

La hoja de onboarding que abre «Comenzar» (`welcome_gate.dart:94-102`) ocupa una región usable completa, con cerrar o saltar fuera de divisiones y oclusiones activas. No se rediseña su contenido. Al plegar, la hoja no se vuelve a presentar y no se escribe `onboarding_state` otra vez. Hereda la continuidad de P10.

## Tarea firma

«Encontrar una crossbody café, verla, elegir variante y comprarla.» Ningún paso existe solo en la pantalla interior. La copia de los botones que ya está en el código se conserva: «AGREGAR A BOLSA», «COMPRAR AHORA», «Continuar al checkout».

En todas las posturas el orden es el mismo. Cambia el lugar, no el paso.

1. Llegar a Catálogo, abrir Crossbody y aplicar el filtro de color de la pieza café. El filtro y el conteo quedan junto a los resultados.
2. Elegir la pieza. La selección es el id de producto y el id de variante, no el índice de la lista.
3. Ver otra foto si hay más de una. La página de la galería se conserva.
4. «AGREGAR A BOLSA» una vez. La bolsa queda con una línea de esa variante, cantidad 1.
5. Abrir Carrito y seguir a la hoja nativa de Shopify solo con un toque explícito. Cancelar vuelve a la misma bolsa. **Pendiente de revisión del tester de pagos.** Esta spec no ejecuta ese pago.

### Por postura

**P1.** Una columna. Riel en el borde del snapshot (observado a la derecha, inset 84, bottom 34). La acción primaria queda bajo el nombre y el precio, fuera de las oclusiones del spike. El primer viewport muestra foto contenida, nombre, precio y la acción, o la acción queda al alcance sin quedar debajo del riel. Al cerrar desde otra postura, esta es la página de detalle si había una pieza elegida; Atrás vuelve al ancla de Crossbody.

**P2.** Los mismos pasos, alto corto. Lo primero que se suelta es el cromo, no el paso. La barra horizontal, si el snapshot dice `none`, puede pasar al menú de overflow que ya existe cuando no cabe el alto mínimo de tarea (`monetta_bottom_navigation.dart:193-218`). Con riel (el snapshot de las capturas 07/08 dijo izquierda), los cuatro destinos siguen en el riel y el contenido usa el resto. El campo de búsqueda y los filtros desplazan. La acción primaria de la ficha y «Continuar al checkout» quedan en zona alcanzable: fijos al borde inferior usable si el alto no los muestra, nunca bajo el riel ni bajo una oclusión. Teclado abierto: el inset del teclado recorta esa zona; el botón sube con él.

**P3.** Al abrir, la colección filtrada sigue montada y la pieza queda al lado. La banda inactiva no es un muro: se usa como guía del corte solo si los dos paneles siguen cumpliendo 320 y 340 pt y el alto 480. Si no, vale el ratio que ya calcula `BrowseDetailLayout` (cerca de 0.42 para el listado, `browse_detail_layout.dart:211-224`). La acción primaria pertenece al panel de detalle. Elegir otra pieza cruza con 180 ms. El filtro no se reinicia.

**P4.** Barras horizontales porque el snapshot trae `barEdge: none`. El ancho observado (669) está bajo `splitWidth` (700), así que la spec de hoy es una columna: foto contenida con alto tope cerca del 55 % del alto usable (`product_adaptive_body.dart:140-144`), luego nombre, precio, variante y acción en el primer viewport. La banda horizontal inactiva no parte la ficha. Atrás vuelve a Crossbody con el ancla. No es P6: la división no está activa.

**P5.** División vertical activa. Listado entero en el lado leading, detalle en el trailing, o bien galería y compra en esas dos regiones (`product_adaptive_body.dart:54-106`). Nombre, precio, variante y «AGREGAR A BOLSA» van juntos en la región de compra, visibles al entrar a esa región, sin cruzar el corte. La foto no se estira. El riel, si el snapshot lo pide, evita la división (`adaptive_storefront_scaffold.dart:163-184`).

**P6, provisional.** Si el check reporta la división horizontal activa: la colección o la galería ocupan la región de arriba; variante y «AGREGAR A BOLSA» ocupan la de abajo, enteros. El listado puede desplazar a través del pliegue solo cuando es una lista continua; los botones no (111463: el contenido que se desplaza no se desplaza fuera, los controles sí se agrupan). Si el check no produce la región, este párrafo no se activa y no hay un modo sentado.

**P7.** Los pasos de la postura que coincida con el snapshot. No se añade un modo tienda. Si el host presenta el exterior, P1 o P2 tienen que poder terminar la compra.

**P8.** Los mismos pasos dentro de la ventana. El borde de la barra es el de esa ventana: a la izquierda si el snapshot dice `left` (la app izquierda del Split View, según el HIG). Por debajo de 700 × 480, o con texto grande, una columna. Los extremos angostos no pierden «AGREGAR A BOLSA» ni Atrás. Redimensionar no lanza checkout ni suma una línea. Slide Over: sin diseño propio hasta que el check de `CAPTURE_PLAN.md` diga si el simulador tiene esa pose.

**P9.** La tarea no usa la otra pantalla. Un solo carrito, una sola hoja.

**P10.** A mitad de la tarea, abrir, cerrar, rotar o plegar:

- Con el teclado abierto en Búsqueda o en un filtro: el texto, el foco y la generación de búsqueda se quedan. No se relanza la consulta.
- Con la hoja de filtros o de vista rápida abierta: la hoja se mueve a una región usable; Cerrar sigue alcanzable; la selección del formulario no se borra.
- Con un agregado en vuelo («AGREGANDO…», `_adding`): exactamente una mutación y una línea al terminar. El botón no acepta otro toque.
- Con la reconciliación de la bolsa antes de la hoja, o con la hoja de Shopify abierta: una sola presentación, una línea, el mismo estado. Cancelar muestra el estado de revisión que ya existe y no abre otra hoja. **Pendiente de revisión del tester de pagos.**
- Con el login abierto: una sola llamada a `login()`.
- El logo, si aún se escribía, salta al final salvo que la caja no haya cambiado de tamaño.
- No hay crossfade de pliegue. No se reinicia la bienvenida. No se vuelve a emitir una impresión por el reflujo. Hoy `EventType.impression` existe y nadie en `lib/` lo emite en esta rama (revisión del tester). Si más adelante se emite, una vez por pieza y por sesión.

## Matriz

Leyenda: la celda vacía no existe. «Hereda» es la spec. El estado de implementación está en `GAP_ANALYSIS.md`.

Overlays de accesibilidad: la regla de arriba, en todas.

### Welcome y onboarding

| Postura | Layout | Navegación | Acción primaria | Hojas | Tipo e imagen | Al entrar y salir | Motion |
|---|---|---|---|---|---|---|---|
| P1 | Columna en el área usable. Caja del logo final desde el frame 0. | Sin destinos todavía. | «Comenzar» abajo, fuera de oclusión y riel. | Onboarding en región usable. | Wordmark contenido, proporción del PNG ≈ 3.47:1. | Primera vez anima; luego estático. | Escritura A, 1000 ms, o salto. |
| P2 | Hereda P1 en alto corto. El botón va fijo abajo. | Igual. | Igual, del lado libre del riel reportado. | Igual. | La caja no crece para llenar el alto. | Igual. | Si rota desde P1, salta al final. |
| P3 | Texto y logo en un lado de la banda inactiva. | Igual. | «Comenzar» entero en un lado. | Igual. | Puede cruzar la banda solo si no está activa y P5 no es inminente; la recomendación es no cruzarla. | Igual. | Escritura A si es la primera vez. |
| P4 | Columna alta. Logo sobre la banda inactiva. | Igual. | Bajo el texto, fuera de la banda. | Igual. | Igual. | Igual. | Escritura A. |
| P5 | Caja y botón en regiones distintas si caben; si no, la región mayor. | Igual. | Fuera de la división activa. | La hoja no cruza el corte. | Igual. | No reinicia. | Escritura A solo si arranca aquí y `logoWritten` es falso. |
| P6 | Provisional: logo arriba, «Comenzar» abajo. | Igual. | Región inferior. | Hoja en una sola región, de preferencia la inferior. | Igual. | Igual. | Igual que P5. |
| P7 | Hereda el snapshot. | Hereda. | Hereda. | Hereda. | Hereda. | Hereda. | Hereda. |
| P8 | Caja de esa ventana. | Hereda. | Área usable, borde reportado. | Dentro de la ventana. | Igual. | Un resize salta al final. | No se reinicia. |
| P9 | No hay segunda bienvenida. | — | Un solo «Comenzar» en la escena activa. | — | — | — | — |
| P10 | Caja nueva sin interpolar. | — | Sigue activo. | La hoja de onboarding no se duplica. | — | `logoWritten` se conserva. | Salta al final si la caja cambió. |

### Inicio

| Postura | Spec |
|---|---|
| P1 | Hero editorial corto, búsqueda, novedades, estilos y marcas, en el orden que ya configura la tienda. Riel en el borde reportado. El primer viewport muestra el hero y el primer grupo. Las etiquetas de estilo no se cortan con puntos suspensivos. |
| P2 | Hereda P1. El hero baja de alto antes de recortar títulos. Si el riel no cabe en vertical, overflow de destinos. |
| P3 | La misma jerarquía, más ancha. El alto de la imagen del hero tiene tope. No aparece una sección nueva por estar abierto. La banda inactiva no parte una tarjeta. |
| P4 | Hereda P1 en columna ancha, con barras horizontales. La banda inactiva no parte el hero. |
| P5 | El hero y los carriles se reacomodan sin cruzar la división activa. El ancla de scroll (id de sección, no un pixel fijo) se conserva. |
| P6 | Provisional: el hero en la región de arriba; la primera acción (búsqueda o un destino) queda en la de abajo si no cabe arriba sin cruzar el corte. |
| P7 | Hereda el snapshot. El exterior tiene que seguir siendo usable. |
| P8 | Hereda P1 o P3 según `canSplit` de **esa** ventana y el `barEdge` reportado. |
| P9 | No hay un segundo Inicio. |
| P10 | No se reinicia el hero ni se repite una impresión. Sin crossfade de pliegue. |

### Catálogo, colección y marca

| Postura | Spec |
|---|---|
| P1 | Una rejilla que ya mide el ancho local (`StorefrontLayout.columns`). Filtros y orden junto al conteo. Abrir una pieza es la página siguiente. |
| P2 | Menos columnas primero. El conteo y «Ordenar» permanecen. La tarjeta no recorta el nombre. |
| P3 | Colección y pieza elegida a la vez. La tarjeta elegida tiene marca que no depende solo del color (el borde de `ProductResultAnchor`, `browse_detail_layout.dart:360-371`). Abrir la galería completa sigue siendo explícito. |
| P4 | Hereda P1: bajo 700 pt de ancho no hay dos paneles. Atrás restaura el ancla por id. |
| P5 | Listado y detalle cada uno en un lado. Si no caben, el detalle ocupa la página y Atrás vuelve al ancla. |
| P6 | Provisional: resultados arriba; si hay pieza elegida, su compra abajo. Si no cabe, hereda el colapso de P5. |
| P7 | Hereda el snapshot. |
| P8 | Hereda P3 solo si la ventana cumple `canSplit` y las dos regiones. Si no, P1. El riel del lado reportado. |
| P9 | No hay un segundo catálogo. |
| P10 | Consulta, facetas, orden, id elegido y ancla se conservan. Al colapsar, el detalle es la página; al volver a abrir, no se duplica el estado. |

Marca hereda colección. No tiene una jerarquía distinta.

### Búsqueda

| Postura | Spec |
|---|---|
| P1 | Campo, sugerencias y resultados en una columna. El teclado no tapa el campo ni la primera sugerencia. |
| P2 | Hereda P1. El campo queda sobre el teclado. |
| P3 | Resultados y detalle conviven si `canSplit`. Si no, hereda P1. |
| P4 | Hereda P1 por el ancho observado. |
| P5 | Hereda P3 con el corte activo. El campo queda entero en un lado. |
| P6 | Provisional: campo y resultados arriba; la pieza elegida, abajo. El campo no cruza el corte. |
| P7 | Hereda el snapshot. |
| P8 | Hereda según el ancho de la ventana. |
| P9 | No hay un segundo campo. |
| P10 | Texto, foco y generación de búsqueda se conservan. Cambiar el tamaño no relanza la consulta ni duplica una impresión. |

### Producto (junto al listado, y directo)

| Postura | Spec |
|---|---|
| P1 | Galería contenida, nombre, precio, variante, existencia y acción. El alto de la foto tiene tope para que nombre y precio entren pronto. La ruta directa no fabrica una colección de origen (`duo_shopping_task_test.dart:197-212`). |
| P2 | Hereda P1. La acción queda en zona alcanzable del alto corto. |
| P3 | Galería y detalle en columnas, cerca de 52/48 cuando el ancho local lo permite (`product_adaptive_body.dart:123-135`). La acción es del panel de detalle. Junto al listado, el origen sigue montado. |
| P4 | Columna. Foto con tope. Nombre, precio y acción en el primer viewport. Barras horizontales. |
| P5 | Galería en una región, grupo de compra en la otra. Nombre y precio van con el botón, no se quedan del otro lado del corte. |
| P6 | Provisional: galería arriba, compra abajo, grupos enteros. |
| P7 | Hereda el snapshot. |
| P8 | Hereda P3 o P1 según la ventana. La acción no asume el borde derecho. |
| P9 | No hay una segunda ficha. |
| P10 | Id de producto, id de variante, página de galería, zoom compatible, secciones abiertas y `_adding` se conservan. Sin crossfade al reacomodar. Compartir pide un rectángulo fresco después del cambio (`product_screen.dart:138-154`). |

### Filtros y orden

| Postura | Spec |
|---|---|
| P1–P2 | Hoja con Cerrar alcanzable, por encima del teclado y fuera de la oclusión. |
| P3–P4 | Hoja o panel acotado al área usable. No se asume que un modal centrado esquive el pliegue solo. |
| P5–P6 | La hoja ocupa una sola región usable. Cerrar no cruza la división activa. P6 sigue provisional. |
| P7–P8 | Hereda la postura del snapshot de esa ventana. |
| P9 | No hay una segunda hoja. |
| P10 | Borrador y errores se conservan. Cerrar no aplica. Aplicar no se dispara por el pliegue. |

### Vista rápida

Hereda Filtros en hoja y región. Además: la variante elegida es explícita; cerrar no agrega a la bolsa; un agregado en vuelo sigue el mismo `_adding` de la vista rápida (`quick_view.dart`, el mismo patrón que la ficha). En P5 y P6 la hoja no cruza el corte. En P10 no se abre sola al plegar.

### Guardados

| Postura | Spec |
|---|---|
| P1–P2, P4 | Rejilla de guardados y vacío claro («no tienes piezas guardadas» o la copia que la pantalla ya usa; no se inventa otra). |
| P3, P5 | Rejilla y detalle de la pieza elegida, con las mismas reglas que Catálogo. |
| P6 | Provisional: rejilla arriba, detalle abajo. |
| P7–P8 | Hereda el snapshot. |
| P9 | Un solo estado de guardados, el que ya comparte la app. |
| P10 | Guardar o quitar no se repite al cambiar de postura. |

Comparar dos piezas no entra a este lanzamiento (DUO-08 sigue en el plan anterior, prioridad P1, fuera de este paquete).

### Carrito

| Postura | Spec |
|---|---|
| P1 | Lista y cantidades primero. El total y «Continuar al checkout» después, alcanzables. Una línea se ve entera, nombre con wrap. |
| P2 | Hereda P1 en alto corto. El paso y el total no se recortan. Si el split de 860 pt no cabe, una columna. El riel del snapshot (las capturas 07/08 lo vieron a la izquierda). |
| P3 | Dos columnas solo si el ancho local llega a `cartSplitWidth` (860) y `canSplit` (`checkout_screen.dart:378-381`). Si el ancho observado de 951 menos el riel no llega, una columna: no se fuerza el split. |
| P4 | Hereda la regla de ancho local. Con barras horizontales. |
| P5 | El resumen y «Continuar al checkout» enteros en una región. La lista puede desplazar. |
| P6 | Provisional: líneas arriba, resumen y continuar abajo, enteros. |
| P7–P8 | Hereda el snapshot. En una ventana estrecha, una columna. |
| P9 | Un solo carrito. |
| P10 | No se recrea el controlador. Un pliegue no cambia cantidades. Texto grande: el encabezado ya se apila (`checkout_screen.dart:385-398`, captura 08a, **simulator**). |

**Pendiente de revisión del tester de pagos.**

### Entrega al checkout

La hoja es de Shopify. Monetta no dibuja el pago. En todas las posturas la hoja la presenta el coordinador, una vez, desde un toque. P5 y P6 no meten la hoja sobre el corte: es una hoja del sistema; lo que Monetta controla es no lanzarla dos veces y no perder la bolsa al volver. P8: la presentación pertenece a la escena que inició el toque. P9: no hay una segunda hoja en la otra pantalla. P10: abrir, plegar, rotar o cerrar con la hoja abierta no llama a `present` otra vez, no muta la bolsa y no repite OAuth.

Cancelar vuelve a la misma pantalla de checkout con el estado de revisión ya implementado («Estamos revisando tu pago» en la prueba de widget, `test/features/checkout/duo_checkout_continuity_test.dart:137-142`). La bolsa sigue con una línea, cantidad 1. Volver a pagar abre una hoja. **Pendiente de revisión del tester de pagos.** No verificado en simulador ni en hardware.

### Cuenta

| Postura | Spec |
|---|---|
| P1–P2, P4 | Lista de filas a detalle. Ancho de lectura cómodo, sin estirar la columna al máximo si sobra espacio: margen de panel 24. |
| P3, P5 | Lista y detalle si las dos regiones caben; si no, la lista o el detalle en la región mayor. |
| P6 | Provisional: identidad arriba, filas abajo, sin una fila cruzada. |
| P7–P8 | Hereda el snapshot. |
| P9 | Una sola sesión. |
| P10 | La sesión no se recrea. Un pliegue no llama a `login()`. |

### Pedidos y detalle de pedido

Hereda Cuenta. El detalle de un pedido conserva el id elegido al plegar. No se vuelve a consultar el pedido porque cambió la geometría. Vacío y error ocupan la región usable. **Pendiente de revisión del tester de pagos** en lo que toca a volver de un checkout cancelado hacia Pedidos: la revisión estática dice que cancelar no navega solo a la bolsa ni crea otro checkout (`CHECKOUT_REVIEW`, sección 5).

## Pantallas por regla

- **Rewards** (`lib/features/rewards/rewards_guide_screen.dart`, fila en Cuenta): hereda Cuenta. El saldo no se convierte en un banner más grande en la interior. Un pliegue puede repetir una lectura; no puede repetir `login()`.
- **Notificaciones** (`lib/features/notifications/notifications_screen.dart`): hereda Cuenta, lista a detalle. La hoja de ajustes de avisos hereda Filtros.
- **Ajustes:** no hay una pantalla con ese nombre. «Preferencias» abre personalización (`account_screen.dart:315-319`) y hereda Cuenta. La hoja de avisos hereda Filtros.
- **Mayoreo y partner** (`wholesale_screen.dart`, `partner_hub_screen.dart`): heredan Cuenta. No ganan un layout de boutique distinto en la interior.
- **Contacto** (`contact_screen.dart`, fila «Ayuda y contacto»): hereda Cuenta. El formulario hereda la regla de teclado de Búsqueda.
- **About** (`about_monetta_screen.dart`): hereda Inicio en cuanto a reflujo editorial, sin tarea de compra. El texto corre en la región usable.
- **Admin** (`admin_screen.dart`): interna. Hereda la columna de Cuenta en cualquier postura y no forma parte del lanzamiento Duo.

## Lo que esta spec no hace

No añade comparación, arrastrar, Pencil, AR ni multiventana al lanzamiento. No fija 84 pt ni 40 pt en el código. No declara una pose verificada en hardware. No declara el pago listo.
