# Resultado de la revisión de fidelidad móvil · H01–H03

**Fecha:** 18 de octubre de 2026, America/Monterrey.  
**Resultado:** los tres hallazgos de [la revisión](../audit-2026-10-18/REVISION_FIDELIDAD_MOBILE.md) quedan corregidos en `design-prototype/` y comprobados en el navegador. **D11 se cierra** con la evidencia de este documento. Quedan diferencias deliberadas y vistas fuera de alcance, listadas al final.

La fuente de diseño fue el código actual de la app (`monetta_page_header.dart`, `product_header.dart`, `product_screen.dart`, `product_card.dart`) y sus capturas de la auditoría. La carpeta `audit-2026-10-18/` no se modificó: es la evidencia del estado previo. Las capturas de esta carpeta son del estado posterior.

## Resumen de cifras

Medidas en Brave/Chromium 155, mismo script de medición que la auditoría (`web/metrics.json`). «Bajo el aviso» descuenta los 28 px del aviso de prototipo.

| Hallazgo | Medida | Antes | Después | App |
| --- | --- | --- | --- | --- |
| H01 colección, 375 y 440 | Primera tarjeta bajo el aviso | 323,6 px | **140,8 px** | 88 px |
| H01 búsqueda, 375 / 440 | Primera tarjeta bajo el aviso | 344,4 / 318,8 px | **206 px** | 221,5 px |
| H01 colección y búsqueda | Ancho de tarjeta, 375 / 440 | 161,5 / 194 px | **181,5 / 214 px** | 181,5 / 214 px |
| H01 bolsa | Encabezado | barra global de 61 px y título debajo | **una barra de 76 px** (volver · Mi bolsa · contador) | una barra |
| H02 ficha | Controles del encabezado | Volver · Menú · Logo · Buscar · Bolsa | **Volver · Buscar · Logo · Cuenta · Bolsa** | igual |
| H03 recomendaciones | Rol del título | Playfair 24/400 | **Inter 17/600** | Inter 17/600 |
| H03 recomendaciones | Tarjeta, 375 / 440 | 135 / 158,4 px (36vw) | **195 / 228,8 px (52vw)** | 52vw |
| H03 recomendaciones | Foto y nombre | cuadrada, una línea | **4:5, dos líneas** | 4:5, dos líneas |
| Inicio | Novedades | Playfair 24/400, tarjeta compacta de 135 px, primera tarjeta en y = 396,6 | **sin cambios** | y = 396,1 |

## H01 · Encabezados interiores en teléfono

**Antes.** Colección, búsqueda y bolsa apilaban barra global, migas, título, atajos y filtros, y no tenían una acción de volver.

**Después.** En teléfono (< 768 px) las tres pantallas abren con la **barra de página** de `monetta_page_header.dart`: 48 px de volver, título Playfair 28 y las acciones de la pantalla al borde derecho. Queda fijada bajo el aviso al desplazar y dibuja su línea al hacerlo.

- **Colección y marca:** volver · título con el contador («58 piezas») debajo · buscar · filtrar y ordenar con el número de filtros activos. Desaparecen la barra global, las migas y la fila «Filtrar y ordenar». La fila de atajos de estilo se conserva como una sola fila desplazable. Con título de dos líneas (320 px) la barra crece, como la de la app.
- **Búsqueda:** barra «Buscar» con volver y filtros (solo si hay resultados), campo de 52 px con la línea divisoria de la app y encabezado de resultados en Inter 20/600 con el contador al lado. Con sugerencias abiertas, los filtros y los resultados se ocultan juntos. Una búsqueda vacía abierta desde otra pantalla enfoca su campo, como la app (una carga directa no abre el teclado).
- **Bolsa:** volver · «Mi bolsa» · «3 artículos» en una fila, con la línea fina bajo la barra desde el inicio (en la app, la primera línea dibuja su borde superior justo ahí); las líneas empiezan 16 px debajo.
- **Cuadrícula:** borde a borde en teléfono (dos columnas de (ancho − 12)/2 con 12 px de separación), como `ProductCardSliverGrid`, con celdas de igual altura por fila.
- **Flecha de volver:** sale de la pantalla en lugar de recorrer los filtros del historial. Si la visita empezó en esa pantalla va al padre (Inicio; «Bolsas» para un estilo). **El botón Atrás del navegador sigue deshaciendo cada filtro y orden** y la URL conserva todo el estado.
- **Accesibilidad:** objetivos de 48 px; el `h1` sigue siendo uno por página y recibe el foco al navegar; `scroll-padding` reserva el aviso y la barra, de modo que el foco por teclado no queda tapado; el contador es una región `aria-live`; los filtros anuncian cuántos hay activos.
- **Tablet y escritorio no cambian:** encabezado global, migas, título con contador, barra de herramientas y barra lateral. Comprobado a 768, 1024 y 1440.

**Diferencia que se mantiene a propósito:** la primera tarjeta queda 52,8 px más abajo que en la app. Es la fila de atajos de estilo (Todas las bolsas · Totes · Crossbodys…), navegación web que la app no tiene en la colección. Con una colección sin atajos (por ejemplo Relojes) la primera tarjeta empieza a la misma altura que en la app.

## H02 · Encabezado de la ficha en teléfono

**Después.** `product_header.dart`: **volver y buscar** a la izquierda, **logo centrado**, **cuenta y bolsa** a la derecha, cada uno de 48 px y con 4 px de margen en los bordes. El menú ya no ocupa el lugar de la búsqueda y cuenta vuelve a estar a un toque. Cuenta abre la entrada `/account` del prototipo, que explica el acceso alojado en Shopify; buscar abre la búsqueda con el campo enfocado. Tablet y escritorio conservan menú, buscador y utilidades.

## H03 · Recomendaciones de producto

**Después.** «Más de {marca}» y «Vistas hace un momento» usan el nuevo rol `product-section-title`: Inter 600, 17 px en teléfono (20 en tablet y 22 en escritorio, donde la página es más ancha). Sus carruseles tienen una variante propia (`rail--recs` con tarjetas `card--flush`): tarjetas de **52vw** (con tope de 260 px en teléfonos grandes), **foto 4:5 a ras de la tarjeta sobre blanco** (`photoInset: 0` de la app), **nombre de dos líneas**, y altura igual dentro del carrusel. En escritorio muestran cinco tarjetas desde 1200 px para quedar cerca del tamaño de la cuadrícula.

Inicio **no cambió**: «Novedades» conserva el encabezado Playfair y la tarjeta compacta (36vw, foto cuadrada, una línea). «Reseñas», que está entre las dos secciones, adopta el mismo rol Inter para que la ficha no mezcle encabezados (la app no tiene reseñas; es una decisión reversible de una línea de CSS).

## Cambios necesarios que no estaban en la lista

- **Foco al abrir Buscar.** El código ya intentaba enfocar el campo (como la app), pero el router movía después el foco al `h1`. Ahora respeta el foco que coloca la página. Sin esto, el acceso a búsqueda de la ficha abría la pantalla sin campo enfocado.
- **Estado de historial por pantalla** (`idx` y `entry` en `history.state`) para que la flecha pueda salir de la pantalla; con pruebas unitarias.

## Verificación ejecutada

Desde `design-prototype/`, Node 24.21.0, Brave/Chromium 155 ya instalado. Compuerta final terminada el 18/10/2026 a las 16:06 (hora de Monterrey).

| Comando | Resultado |
| --- | --- |
| `npm test` | **31/31** (25 anteriores y 6 nuevas de navegación) |
| `npm run build` | correcto: CSS 66,07 kB (12,37 gzip), JS 271,36 kB (60,73 gzip) |
| `npm run verify -- --out=../docs/web-redesign/fidelity-2026-10-18/evidence` | **153/153 en 170 s**: D02 10 · D03 35 · D05 6 · D06 8 · D07 5 · D08 3 · D09 44 · **D11 41 nuevas** · D10 1. [Informe](evidence/verify-report.json) |
| `npm run capture:fidelity` | 26 capturas, `web/metrics.json` y `comparacion.html`; 0 errores de página, consola o red; 0 desbordes horizontales |
| `npm run capture -- --out=../docs/web-redesign/fidelity-2026-10-18/screenshots` | 58 capturas; 0 errores; 0 desbordes. [Índice](screenshots/index.json) |

Las 112 comprobaciones anteriores seguían pasando con los cambios, pero no demuestran fidelidad con Flutter. Por eso se añadieron 41 comprobaciones independientes (`verify/check-fidelity.mjs`) que miden contra hechos leídos del código de la app: controles visibles y su orden, objetivos de 44 px, el rol tipográfico, el ancho, la proporción y las líneas de las tarjetas, cuánto cromo queda sobre el primer producto, la barra fijada, el foco no tapado, la flecha de volver con el Atrás del navegador, y que tablet y escritorio no cambian.

**Prueba de que las comprobaciones pueden fallar.** Se reintrodujo a propósito el comportamiento anterior en copias de los fuentes y las comprobaciones lo detectaron: con el encabezado global, la barra de herramientas y el menú en la ficha, 22 de 39 fallaron (la primera tarjeta quedaba a 287,8 px frente a un presupuesto de 140,8); con `scroll-padding` en cero, fallaron las tres del foco; con tarjetas de distinta altura, fallaron las de carruseles (347 frente a 367 px); sin la línea de la barra de la bolsa, fallaron las tres de la bolsa. Después de cada prueba se restauraron los fuentes y se comprobó que eran idénticos.

## Inspección visual

Se abrieron como imágenes y se compararon con las capturas de la app y con las del estado previo:

- **375×812 y 440×956:** Inicio, colección, ficha (encabezado), recomendaciones («Más de» y «Vistas»), búsqueda y bolsa. Además, la colección desplazada, la marca con filtros y el título largo («Tommy Hilfiger» en una línea a 375 y en dos a 320), la búsqueda vacía, sin resultados y con sugerencias, el cajón de filtros abierto desde la barra, la colección sin resultados y la bolsa vacía.
- **768 y 1440:** Inicio, colección, ficha, búsqueda, bolsa y los carruseles de recomendaciones.
- Se corrigieron durante la revisión: el título de tablet que había bajado a 28 px, las tarjetas de distinta altura en los carruseles y el foco de la búsqueda.

[`comparacion.html`](comparacion.html) muestra app · antes · después con las cifras de cada pantalla.

## Alcance, límites y pendientes

- **Otras vistas interiores en teléfono** (Favoritos, Cuenta, Mayoreo, Historia, Contacto, políticas y 404) conservan el encabezado global. La app usa el mismo encabezado de página en todas; extenderlo es mecánico con `pageBar`, pero no formaba parte de H01–H03.
- **Diferencias deliberadas con la app,** ya documentadas en `DESIGN_SPEC.md` §9: contador de piezas visible (la app lo muestra solo a administradores), corazones en las tarjetas, precios anteriores y descuentos genuinos, la fila de atajos y la acción de buscar en la barra de colección.
- Las capturas Flutter son las de la auditoría (no se regeneraron): son renderizados de widgets con productos de otro snapshot y fotos como marcador. No se comparó píxel a píxel entre motores.
- Sin verificar: dispositivos reales, Safari, Firefox, lectores de pantalla y comportamientos de Shopify (ver `VERIFICATION.md`). La flecha de volver por pantalla necesita su propia implementación en un tema de varias páginas (ver `IMPLEMENTATION_HANDOFF.md` §4).
- El set `docs/web-redesign/screenshots/` del 17 de octubre se conserva como histórico; no se actualizó. El set vigente está en `screenshots/` de esta carpeta.

## Archivos

- **Prototipo:** `src/components/page-bar.js` (nuevo), `shell.js`, `ui.js`, `src/lib/router.js`, `src/main.js`, `src/pages/{listing,collection,search,cart,product}.js`, `src/styles/{components,pages}.css`, `tests/unit/navigation.test.mjs` (nuevo), `verify/check-fidelity.mjs` y `verify/capture-fidelity.mjs` (nuevos), `verify/run-all.mjs`, `verify/capture.mjs`, `package.json`, `README.md`.
- **Documentos:** `STATUS.md`, `DESIGN_SPEC.md`, `VERIFICATION.md`, `IMPLEMENTATION_HANDOFF.md`, `FINAL_REPORT.md` y esta carpeta.
- **Sin tocar:** `audit-2026-10-18/`, `docs/prompts/` (incluido el prompt del 17 de octubre), Flutter y backend, `.claude/` y cualquier secreto o configuración. Sin commits ni pushes.
