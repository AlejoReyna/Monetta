# Plan de implementación · DUO-11 en adelante

Sigue la numeración de `docs/IPHONE_DUO_DESIGN_AND_LAUNCH_PLAN.md` (DUO-01–DUO-10). Esos ítems no se reabren aquí. DUO-01 a DUO-06 tienen una implementación en `738a61f` con los huecos de `GAP_ANALYSIS.md`. Este plan cubre esos huecos. No cambia código.

Los rangos son **estimaciones**, no un compromiso de calendario. No se traducen a semanas.

Nada de esto está verificado en hardware. Las pruebas de pago no declaran el pago listo. Las celdas de checkout, OAuth y la bolsa quedan **pendiente de revisión del tester de pagos**.

Regla para cualquier ítem que toque la postura: el estado de checkout y de bolsa vive solo en el coordinador, `CartController` y `CatalogStore`. Ningún callback de layout llama a agregar, a `present` ni a `login`. El widget que cambia de postura conserva tipo y key en el mismo slot, o usa `GlobalKey`.

## Backlog

| ID | Pri | Entrega | Sale de | Depende de | Criterio | Pruebas | Estimación |
|---|---|---|---|---|---|---|---|
| DUO-11 | P0 | Escritura del logo en Welcome, variante A, 1000 ms, caja final desde el frame 0. «Comenzar» activo en el frame 0. Quitar el bloqueo de `AbsorbPointer` / `ExcludeFocus` de `StartupReveal` sobre ese botón (`startup_reveal.dart:66-112`). No sumar los 1100 ms. No reutilizar el clip 30/132. | ❌ Welcome. Decisión del owner, 28 oct 2026. Spec del Director @ `fbeac82`. | Ninguno de app. El Director revisa el resultado. | P1, P3, P4 y P10 como `DESIGN_SPEC.md`. Reduce Motion muestra el PNG completo. Un cambio de `Size` de la caja salta al final y no se reinicia. | Sintéticas del §10 de la spec de movimiento: frame 0, 220 ms, 1000 ms, pliegue a 500 ms, «Comenzar» sin ancestro `AbsorbPointer`. Un `flutter drive` P1→P3 durante la escritura, cuando el target exista. | 2–4 días de ingeniería, estimación |
| DUO-12 | P1 | **Propuesta, no aplicar todavía.** Token `logoWrite: 1000` en `design-system/monetta.tokens.json`. Hoy no están `enter` ni `kenBurns`. | Spec del Director, §2. | DUO-11, para no regenerar tokens antes de tiempo. | El token existe y el widget lo lee. No se parchea un archivo generado a mano. | El test de duración lee el token, no un literal suelto. | menos de 1 día, estimación, cuando se apruebe |
| DUO-13 | P2 | **Propuesta, no aplicar todavía.** El splash nativo muestra solo el fondo, sin el logo completo, para no enseñarlo y luego «borrarlo». Es N6, no una regla de Apple. | Spec del Director, §5. | DUO-11. | Arranque en frío: fondo y, después, la escritura o el logo estático. | Captura **simulator** del primer frame. No se afirma fluidez. | cerca de 1 día, estimación |
| DUO-14 | P1 | **Propuesta, no aplicar todavía.** Un interruptor de prueba (`debugForceMotion` o `motionEnabled` en el widget del logo) porque `inWidgetTest` obliga a `reduceMotion` (`motion.dart:29-36`). | Spec del Director, §10.1. | DUO-11. | Los tests de widget normales siguen en movimiento reducido. Solo el test del logo recorre la ruta animada. | El propio test del interruptor. | menos de 1 día, estimación |
| DUO-15 | P0 | **Propuesta de implementación, no aplicar en esta rama.** Persistir `logoWritten` en el aparato, aparte de `onboarding_state` (`welcome_gate.dart:6-16`). Una vez por instalación. Arranque en frío posterior: logo estático. | Decisión del owner. No es pregunta abierta. | DUO-11. Migración de preferencias si hace falta un campo nuevo; no se recicla el flag de onboarding. | Con el flag verdadero, un proceso nuevo no anima. Plegar no lo pone en falso. | Test sintético: flag verdadero → frame 0 ya completo. | 1–2 días, estimación |
| DUO-16 | P0 | Pruebas de geometría **sintética** (divisiones y `barEdge`, no solo tamaño) en tres momentos: agregado en vuelo, sync del `present` antes de la hoja, hoja abierta. Cada una afirma 1 mutación, 1 hoja, 1 línea y el mismo `State`. Más una con el login abierto que afirma una sola llamada a `login()`. | Huecos del tester. `GAP_ANALYSIS.md`, P10. El test de tamaño ya existe y no basta (`duo_checkout_continuity_test.dart:122-130`). | Harness actual. No hace falta P6 confirmado: la división se inyecta. | Esas cuatro afirmaciones. Etiqueta synthetic en el nombre de la prueba. | Las cuatro pruebas. No sustituyen el guion de hardware. **Pendiente de revisión del tester de pagos.** | 2–3 días, estimación |
| DUO-17 | P0 | **S3, propuesto, sin empezar hasta que Alexis lo apruebe.** Bandera de vuelo en `continueToCheckout` (`checkout_screen.dart:294-374`) para que un doble toque en «Continuar al checkout» (`:452`, `:458`) empuje una sola ruta. No es el botón «CONTINUAR AL PAGO SEGURO». | Nota del tester. No es un fallo de postura. El coordinador ya impide dos `present`. | Aprobación de Alexis. | Un doble toque, una ruta. La bolsa no cambia. | Widget test del doble toque. | menos de 1 día, estimación, después del sí |
| DUO-18 | P0 | Cerrar P6 con el check de `CAPTURE_PLAN.md`. Si la división horizontal activa aparece, galería arriba y compra abajo, con el rect reportado. Si no aparece, no se añade un modo. El código ya parte un corte horizontal ancho (`product_adaptive_body.dart:54-64`). | Decisión provisional de `POSTURES.md`. | El coordinador corre el check. | Sin números 455.5 ni 40 escritos como constante. «Comenzar» en P6 como la spec. | Una prueba sintética de división horizontal activa, y un `flutter drive` de esa pose si el simulador la tiene. | 1–3 días, estimación, después del check |
| DUO-19 | P1 | P2: «Continuar al checkout» y la acción de la ficha alcanzables en el alto corto. El riel del lado que diga el snapshot. Dejar de cortar «Crossbo...» en Inicio (captura 01). | ⚠ P1 y P2. | Capturas `p2-inicio` y `p2-product` si se quieren antes de cerrar. | Nombres de pieza con wrap. El botón no queda bajo el riel. | Widget sintético 678 × 466 con `barEdge` left y con right. Un drive de P2 Inicio. | 1–2 días, estimación |
| DUO-20 | P1 | En P3 y P5 el primer viewport de la región de compra muestra nombre, precio y la acción entera. | ⚠ capturas 03 y 05. | Ninguno. | La acción no queda cortada por el borde. En P5 el título va con el botón. | Widget sintético con la división activa de la etapa `partial-fold`, sin copiar 40 pt como constante de producción: el fixture de test sí puede usar el rect observado y debe decir synthetic. | 1–2 días, estimación |
| DUO-21 | P1 | Con división **inactiva**, alinear el corte de browse/detail a esa banda solo si los dos paneles siguen en 320 y 340 y el alto en 480. Si no, el ratio actual. La banda no es un muro. | ⚠ P3. `browse_detail_layout.dart:203-224` ignora la banda inactiva. | Ninguno. | Cambiar la banda de sitio en un fixture mueve el corte. Una banda que rompe los mínimos no parte. | Widget sintético. | 1–2 días, estimación |
| DUO-22 | P1 | P8: ventana estrecha, ventana ancha, borde izquierdo y borde derecho. Misma tarea firma. | pending simulator capture. HIG: la app izquierda lleva los controles a la izquierda. | Capturas `p8-*`. | Ningún literal «riel derecho si el ancho pasa de X». | Cuatro widgets sintéticos de `barEdge`, más un drive por extremo cuando Device Hub lo permita. | 2–4 días, estimación |
| DUO-23 | P1 | Target de `flutter drive` que visite las filas de `CAPTURE_PLAN.md` que el test actual no abre. Hasta entonces las fotos son manuales. | Lista de capturas. | El simulador del owner. No se añade en esta rama de docs. | Un PNG y una línea de JSON por fila, etiqueta simulator. | El propio drive. Comercio de CI sigue apagado. | 2–3 días, estimación |
| DUO-24 | P1 | Crossfade de 180 ms solo en los dos casos de `BrowseDetailLayout` de la spec. Ninguno al plegar, ni en el logo, ni en la galería. | Spec del Director, punto 7. Hoy el cambio de panel no tiene ese fundido acotado. | DUO-14 si el test quiere ver la opacidad. | Plegar no crea un `FadeTransition` propio. Cambiar de pieza sí, 180 ms, solo opacidad. | Widget sintético. Reduce Motion: instantáneo. | cerca de 1 día, estimación |
| DUO-25 | P1 | Overlays que faltan en foto: modo oscuro, Bold Text, Increase Contrast, Reduce Transparency, en P1 Inicio y P3 producto. Texto grande más allá del carrito. | Regla de accesibilidad. Solo el carrito P2 tiene captura AX. | DUO-23. | Sin elipsis en nombres. Contraste de texto fuera del oro. | Las capturas del plan, más un widget de texto grande en la ficha. | 2–3 días, estimación |
| DUO-26 | P2 | VoiceOver, teclado de hardware y alcance. | ❓ | Un Duo físico. | El guion de hardware, pasos marcados al ejecutarlos. | No es un test de widget. | trabajo de QA, sin cifra de feature |
| DUO-27 | P2 | P7: no construir un modo. Solo si el check de Device Hub muestra una geometría que no cabe en P1–P6, volver a estimar. | HIG, «standing on its edges», sin pantalla asignada. | El check. | Cero código si la geometría ya cabe. | Ninguno hasta que el check sorprenda. | el check no es un cambio de app |
| DUO-28 | P2 | P9 se queda diferido. No hay escena doble ni accessory de cámara. | Decisión de `POSTURES.md`. 111464. | Un pedido explícito del owner para salir de aquí. | `UIApplicationSupportsMultipleScenes` sigue en falso. | Ninguno. | sin trabajo de app |
| DUO-29 | P1 | No emitir impresión ni `productView` en un reflujo. Si más adelante hay impresiones, una por pieza y por sesión. | Tester, sección 4. Hoy no se emite `impression`. `productView` va en el toque y en Atrás (`browse_detail_layout.dart:122`, `product_screen.dart:89-97`). | Ninguno, salvo que alguien añada impresiones. | Un cambio de snapshot no llama a `logProductEvent`. | Widget sintético que pliega y cuenta eventos. | menos de 1 día, estimación |
| DUO-30 | P1 | Filtros y vista rápida ocupan una región usable. Cerrar queda fuera del corte activo. Aplicar no se dispara al plegar. | pending simulator capture. Las hojas siguen en `showModalBottomSheet` (`quick_view.dart:50`). El host ya publica `displayFeatures` de divisiones activas (`system_layout_context.dart:183-191`). | DUO-16 por el fixture. | Cerrar no intersecta la división activa del fixture. | Widget sintético. | cerca de 2 días, estimación |

DUO-08, DUO-09 y DUO-10 del plan anterior siguen en P1/P2 de producto y **fuera** de este lanzamiento (comparar, arrastrar, intents). No se adelantan.

## Riesgos

- P6 puede no existir en el simulador. Construir un modo «sentado» por ancho sería el fallo que la spec prohíbe. El gate es el check, no el tablero **concept**.
- El borde de la barra en P2 ya salió izquierda y derecha con la misma medida. Un test que fije `right` va a mentir.
- `StartupReveal` y la escritura nueva pueden tapar «Comenzar» dos veces si se apilan. DUO-11 lo tiene como criterio, no como detalle opcional.
- Las pruebas de widget con `inWidgetTest` no ven movimiento. Sin DUO-14, un test verde no demuestra la escritura.
- El doble toque de «Continuar al checkout» puede abrir dos rutas aunque el coordinador impida dos cobros. DUO-17 no empieza sin Alexis.
- Una captura manual sin `DUO_CAPTURE_CONTEXT` no demuestra geometría. `geometryStatus: pending` es el estado honesto.

## Gates

1. El check de P6 queda escrito, aunque sea «el simulador no pliega en vertical».
2. DUO-11 y DUO-15, cuando se implementen, los revisa el Director de Movimiento. El flag es decisión del owner.
3. DUO-16 lo revisa el tester de pagos. Verde ahí no es pago listo ni hardware.
4. DUO-17 no se abre hasta el sí de Alexis.
5. Ningún gate de este plan es «insignia aprobada» ni «App Store listo».

## Preguntas para el owner

1. P6: cuando el coordinador devuelva el `DUO_GEOMETRY` del pliegue en vertical, ¿se confirma la spec o se deja solo el camino genérico de división activa? La spec ya propone lo segundo si el check sale negativo.
2. P7: ¿basta con que el exterior siga pudiendo comprar, sin modo tienda? El plan anterior decía que sí. Esta entrega no lo cambia.
3. P8: ¿Split View entra en el mismo corte que el libro, o puede esperar a después de DUO-11 y DUO-16?
4. P9 queda diferido. ¿Se mantiene así? Hace falta un sí explícito solo si se quiere el accessory de cámara; si no, no hay pregunta.
5. El tamaño fino de la caja del logo en P3 lo dejó abierto el Director (la regla de no cruzar la banda ya está tomada). ¿Lo cierra él con las capturas `p3-welcome`?
6. DUO-17, el doble toque de «Continuar al checkout»: ¿se aprueba el arreglo o se queda propuesto?
7. Los cortes internos de E, T, T y A no están medidos. Los fija el Director sobre el PNG 3x. No es una pregunta de producto.
