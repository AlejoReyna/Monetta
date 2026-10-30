# Corrección de los seis hallazgos de la auditoría GPT — 2026-10-18

Respuesta a [`audit-gpt-2026-10-18/AUDITORIA_GPT.md`](../audit-gpt-2026-10-18/AUDITORIA_GPT.md)
(GPT-01 … GPT-06) sobre el prototipo `design-prototype/`. H02 y H03 se conservaron
(encabezado de la ficha, recomendaciones, diseño de Inicio). **D11 estuvo abierto mientras
los seis puntos no se resolvieron y se comprobaron; queda cerrado el 2026-10-18** tras las
correcciones, la puerta completa y la revisión visual de las capturas (sección 5).

**Resultado en una línea:** `npm test` 49/49 · `npm run build` correcto · `npm run verify`
**204/204** (los 153 anteriores sin tocar + 51 nuevos, D11 92/92) · los 51 controles nuevos
pasan **10/51 contra la versión anterior** y **51/51 contra la corregida** · comparación de píxeles
378/384 idénticas (las 6 restantes: ≤ 4 píxeles de 1/255 de diferencia, ruido que la base también muestra consigo misma).

## 1. Método

1. **Reproducir antes de corregir.** El árbol anterior se archivó a las 16:51 CST
   ([`baseline-pre-correcciones.tgz`](baseline-pre-correcciones.tgz), 59 archivos con sus hashes en
   [`baseline-pre-correcciones.sha256`](baseline-pre-correcciones.sha256)), se compiló aparte y se sirvió
   en `127.0.0.1:4401`; la versión corregida es `design-prototype/dist` en `127.0.0.1:4402`. El mismo guion
   ([`reproducciones.mjs`](reproducciones.mjs)) midió las dos y escribió JSON y capturas en
   [`antes/`](antes/) y [`despues/`](despues/).
   *Para repetir el «antes»:* extraer el archivo en una carpeta nueva (guarda sólo el código: `src/`, `verify/`, `tests/`, `index.html`,
   `vite.config.js`, `package*.json`, `README.md`), enlazar en ella `node_modules`, `public`, `fixtures` y `scripts` de
   `design-prototype/` (no cambiaron), `npx vite build` y `npx vite preview --port 4401 --strictPort`; después
   `node reproducciones.mjs --out=<carpeta> --label=antes --url=http://127.0.0.1:4401` y
   `node design-prototype/verify/check-audit-fixes.mjs --url=http://127.0.0.1:4401`.
2. **Medir lo que ve la persona, no lo que declara el CSS.** Teclado real (`Tab`, `Shift+Tab`), apilado
   pintado (`elementFromPoint`) y píxeles leídos de capturas reales para el foco; pila de historial
   real del navegador para la flecha; árbol de accesibilidad y axe para los encabezados; geometría de
   las barras fijadas; región segura con la emulación de Chromium (CDP). Las sondas compartidas están en
   [`verify/probes.mjs`](../../../design-prototype/verify/probes.mjs).
3. **Pruebas de regresión que fallan por el defecto real.** Los 51 controles nuevos
   ([`verify/check-audit-fixes.mjs`](../../../design-prototype/verify/check-audit-fixes.mjs), puerta D11, nombres
   `GPT-01 … GPT-06` y `A1`) se ejecutaron contra la base —10 pasan (las que protegen comportamiento que debía
   conservarse), 41 fallan por la razón de la auditoría— y contra la corregida —51 pasan—
   ([`logs/check-audit-fixes-base.log`](logs/check-audit-fixes-base.log),
   [`logs/check-audit-fixes-corregido.log`](logs/check-audit-fixes-corregido.log)). Los 153 controles anteriores no se
   tocaron ni se relajó ninguna aserción.
4. **Regresión visual sin cambios no pedidos.** Base y corregida se compararon píxel a píxel (sección 4).
5. **Revisión visual con las capturas abiertas como imágenes** (sección 5).

Entorno: Brave 1.97 = Chromium 155.0.8059.40 (ya instalado; Chrome no se instaló), `playwright-core` 1.63.0,
axe-core 4.13.0, Node 24.21.0, Vite 6.4.3. Puertos 4401, 4402 y 4411 (ordinarios).

## 2. Una tabla por hallazgo

### GPT-01 — Foco oculto por el dock

| | |
| --- | --- |
| **Estado** | **Corregido**, verificado con teclado real (Tab desde el enlace de salto hasta el pie). |
| **Cambio realizado** | `src/lib/chrome.js` (nuevo) mide lo que queda fijo sobre el contenido y lo publica en `<html>` como `--pinned-top` y `--pinned-bottom`; `base.css`: `scroll-padding-top/bottom` = medida + 16 px. La reserva inferior es la altura **real** de la barra de cada página (dock 90 px —no los 88 que la maqueta suponía—, barra de compra, barra de pago), suma el indicador de inicio y se vuelve a medir al renderizar, redimensionar, cambiar la orientación, cargar una fuente o cambiar la clase del `body`; los elementos se observan por su **caja de borde** (el dock crece con su *padding*). No se añadió más relleno al final del documento (no era la causa). Complemento A1 en la sección 3. |
| **Reproducción antes → después** | 390×844, `/collections/guess`: 103 paradas, 19 en el pie; **6** con el control tapado o el anillo cortado (Novedades: caja tapada por `dock__item`, anillo tapado arriba y a la derecha y pintado en 1 de 3 lados; Envíos; Mi cuenta; Cambios y devoluciones; WhatsApp; Contacto) → **0**. Ficha 10 → 0, bolsa 6 → 0, Inicio 21 → 0, búsqueda 6 → 0. En las 19 paradas del pie de cada página se leyeron los píxeles de la captura: anillo pintado en 4 de 4 lados y texto con tinta (≥ 12 píxeles). |
| **Prueba y captura** | 12 controles `GPT-01` (base 0/12, corregida 12/12): la reserva inferior = altura real de la barra + 16 px en colección, ficha y bolsa; crece con un indicador de inicio de 34 px y vuelve; recorrido con Tab de cinco páginas a 390×844 y de colección, ficha y bolsa a 375×812, 440×956 y 320×568; la bolsa a 768×1024 (barra de pago aún fija); los tres enlaces de la auditoría con texto, anillo en 4/4 lados y separación del dock. Capturas: [`antes/gpt-01-foco-oculto.png`](antes/gpt-01-foco-oculto.png), [`revision-visual/B-390x844-foco-novedades.jpg`](revision-visual/B-390x844-foco-novedades.jpg), `…-foco-envios.jpg`, `…-foco-mi-cuenta.jpg`, hoja [`hojas/10-foco-teclado-pie-390.png`](revision-visual/hojas/10-foco-teclado-pie-390.png). |
| **Limitaciones pendientes** | Un control más alto que la banda que dejan las barras (tarjeta de 471–510 px en 320×568, banda de 374 px) lo centra el navegador y sus extremos quedan bajo las barras: no existe posición que muestre ambos; la sonda sólo le exige el centro (criterio explícito en `probes.mjs`). Sólo Chromium 155: sin Safari, Firefox ni lector de pantalla. |

### GPT-02 — Carrera del fallback de navegación

| | |
| --- | --- |
| **Estado** | **Corregido.** |
| **Cambio realizado** | `src/lib/router.js`: un contador de navegaciones (`navigationEpoch`) que suben `navigate`, `popstate`, `updateUrl` y `pageshow` restaurado de la caché de retroceso/avance; `leaveScreen(parent)` (nuevo) captura el contador al hacer clic y su temporizador de 500 ms sólo navega al padre si el contador **sigue siendo el mismo**: el fallback pertenece a la operación que lo armó, no a una comparación de direcciones. `main.js` delega en ella. Se conserva la distinción: la flecha sale de la pantalla (`history.go(-pasos)`), el Atrás del navegador sigue deshaciendo los filtros uno a uno. |
| **Reproducción antes → después** | Inicio → Catálogo → ficha → flecha → Adelante (retroceso a 34 ms, Adelante a 37 ms): base, 900 ms después la URL es `/collections/carteras-1` y se pierde la ficha restaurada; corregida: se queda en la ficha. Controles: Adelante a 0, 150 y 450 ms fallan en la base y pasan; a 700 ms pasan las dos (el temporizador ya había vencido). También fallaban en la base y pasan: reabrir el mismo producto 100 ms después de la flecha (misma dirección que el fallback comparaba) y la flecha desde una pantalla con orden aplicado seguida de dos Adelante. |
| **Prueba y captura** | 6 pruebas unitarias nuevas (`tests/unit/navigation.test.mjs`: historial y temporizadores simulados) y 8 controles `GPT-02` en navegador: Adelante 0/150/450/700 ms; producto reabierto; flecha otra vez tras Adelante; pantalla filtrada (flecha en un paso, dos Adelante, Atrás del navegador sigue deshaciendo el orden); enlace directo (flecha → padre en < 400 ms y Atrás vuelve a la ficha); recarga tras filtros; entradas perdidas (el fallback llega al padre tras 500 ms); Atrás/Adelante del navegador con pausas de 0, 700 y 1500 ms. Base 5/8 (las 5 que protegen comportamiento conservado), corregida 8/8. **Mutación:** con la condición antigua en una copia, fallan exactamente las 3 unitarias de carrera y pasan las otras 3 ([`logs/gpt02-mutacion-condicion-antigua.log`](logs/gpt02-mutacion-condicion-antigua.log)). Capturas: `antes/gpt-02-adelante.png`, `despues/gpt-02-adelante.png`. |
| **Limitaciones pendientes** | El caso de la caché de retroceso/avance sólo lo cubre la prueba unitaria: Playwright la desactiva. Un doble toque rápido en la flecha sigue dejando dos pantallas atrás, igual que antes (probado en las dos versiones): evitarlo es una decisión de producto que la auditoría no pidió. Un retroceso más lento que 500 ms (no observado) sería indistinguible de uno perdido. |

### GPT-03 — Búsqueda sin `h1` accesible

| | |
| --- | --- |
| **Estado** | **Corregido.** |
| **Cambio realizado** | `src/pages/search.js` y reglas en `components.css`. Un solo `h1` expuesto por estado, sin duplicar: sin consulta, o con resultados que no cargaron, el título "Buscar" de la barra es el `h1` en todos los anchos (en ese estado la barra deja de ser sólo de teléfono); con resultados, con o sin coincidencias, el `h1` sigue siendo "Resultados para “q”" y el título de la barra es texto; mientras las sugerencias sustituyen a los resultados el título de la barra toma `role="heading" aria-level="1"` (visible en teléfono; desde tablet visualmente oculto pero en el árbol de accesibilidad, para que el campo no se desplace) y lo pierde al volver. |
| **Reproducción antes → después** | `/search?q=bolsa&type=product`, cinco estados × 390 y 1440. Base: sugerencias y error → **0** `h1` expuestos y axe `page-has-heading-one` (moderate) en los 4 casos (2 estados × 2 anchos). Corregida: **1** `h1` expuesto en los 10 casos (“Buscar”, “Resultados para “bolsa””, “Resultados para “zzzz-no-match””) y **0** violaciones de axe con todas las etiquetas del proyecto. |
| **Prueba y captura** | 3 controles `GPT-03` (base 0/3, corregida 3/3): por ancho, un `h1` expuesto que nombra la pantalla y 0 axe en vacío, sugerencias, resultados, sin resultados y error; flujo resultados → otra consulta → volver a la consulta: un `h1` cada vez, el rol sale con las sugerencias y el campo no se mueve (≤ 0,5 px) en 390 y 1440. Capturas: `antes/` y `despues/` `gpt-03-busqueda-{error,suggestions}-{390,1440}.png`. |
| **Limitaciones pendientes** | Sin lector de pantalla real. El `h1` del estado de sugerencias es un `<p role="heading">`: es el cambio con menos efecto en el diseño; la alternativa, un `h1` oculto, duplicaría “Buscar” para los lectores. |

### GPT-04 — Reserva fija para una barra que crece

| | |
| --- | --- |
| **Estado** | **Corregido.** |
| **Cambio realizado** | La reserva superior ya no es `28 + 76 + 16`: es el borde inferior **medido** de franja + cabecera + barra de página + 16 px (`--pinned-top`). Sigue a la barra cuando el título pasa a dos líneas, cuando llega una fuente web tardía, cuando cambia el tamaño del texto, al redimensionar y al navegar entre páginas; sólo cuenta elementos `sticky` o `fixed`. Desaparece la regla `html:has(body.has-page-bar)`. En tablet y escritorio cuenta por fin la fila de categorías. |
| **Reproducción antes → después** | 320×812 `/collections/tommy-hilfiger`: barra de 97,31 px (borde inferior 125,31). Base: `scroll-padding-top` 120 px; con `nearest` el enlace queda a 120,25 px (**5,06 px bajo la barra**); con `scrollIntoView(start)` 5,38 px; con **Shift+Tab real** hacia una tarjeta asomada bajo la barra, 5,69 px. Corregida: 141,31 px y solape **0** en los tres. Además, en escritorio (1440) la ancla “Ver catálogos” caía 30 px bajo la cabecera (115,6 frente a 146); ahora cae a 162. |
| **Prueba y captura** | 8 controles `GPT-04` (base 2/8 —las dos que no estaban rotas—, corregida 8/8): dos líneas (reserva = borde medido + 16, `nearest`, Shift+Tab real y `scrollIntoView(start)`); título de una línea sin regresión (120 px); texto de 72 px y de vuelta; 375 → 320 → 375; fuente Playfair retenida 1,5 s; colección → ficha → colección; ancla a 390 y a 1440. Capturas: `antes/gpt-04-titulo-largo-nearest.png`, `antes|despues/gpt-04-shift-tab-tarjeta-oculta.png`. |
| **Limitaciones pendientes** | El escenario de Shift+Tab de la primera reproducción (elemento anterior ya visible) no mostraba solape en la base; el que sí lo reproduce parte de una tarjeta medio oculta bajo la barra y está registrado como `keyboardShiftTabPeeking`. Sólo Chromium. |

### GPT-05 — Contenido cubierto con poca altura

| | |
| --- | --- |
| **Estado** | **Corregido.** |
| **Cambio realizado** | Bloque `@media (max-width: 1023.98px) and (max-height: 480px)` al final de `pages.css`: franja, cabecera y barra de página dejan de estar fijadas y se van con la página; el dock pasa al final del documento (estático, sobre el gris del pie); la barra de compra y la de pago se ocultan y toman el relevo los botones que la página ya tiene (el “Agregar al carrito” en línea y el “Continuar al checkout” del resumen de la bolsa). Primera versión: sólo teléfonos (< 768 px); la revisión visual de 812×375 mostró que la bolsa dejaba 164 px y se extendió a < 1024 px. |
| **Reproducción antes → después** | Espacio libre para el contenido tras desplazar, en px, base → corregida. **320×200** (1280×800 al 400 %): Inicio 29→200 · colección 14→200 · ficha 46→200 · búsqueda 14→200 · bolsa 23→200. **360×225** (1440×900 al 400 %): 54→225 · 39→225 · 71→225 · 39→225 · 48→225. **640×400** (1280×800 al 200 %): 229→400 · 214→400 · 246→400 · 214→400 · 223→400. Teléfonos de lado: **667×375** 204·189·221·189·198 → 375; **812×375** 237·237·237·237·164 → 375; **844×390** 252·252·252·252·179 → 390. |
| **Prueba y captura** | 11 controles `GPT-05` (base 1/11, corregida 11/11): las cinco páginas en los seis viewports (≥ 90 % libre, sin desbordamiento); en 320×200, 360×225 y 640×400 el botón de añadir de la ficha, el checkout de la bolsa (abre su diálogo y se cierra), los filtros (el botón de aplicar queda en pantalla), la búsqueda (sugerencias y enlace de resultados) y el dock (en el pie) funcionan y no están tapados; recorrido con Tab a 320×200 de ficha y bolsa; y a 375×812 la franja, la cabecera y el dock **siguen fijos**. Capturas: [`antes/gpt-05-*-{320x200,360x225,640x400}.png`](antes/), [`despues/…`](despues/), inicio y final de cada página en [`revision-visual/C-*.jpg`](revision-visual/) y hojas `12`, `13`, `14`, `15`. |
| **Limitaciones pendientes** | **320×200, 360×225 y 640×400 son equivalentes en píxeles CSS del reflujo (1280×800 y 1440×900 al 400 %, 1280×800 al 200 %), no la prueba con el control de zoom nativo del navegador**; el nombre de cada control y de cada captura lo dice. Con tan poca altura los diálogos se desplazan por dentro (el de checkout muestra encabezado y parte del cuerpo): el reflujo lo permite y el botón de cerrar queda siempre en pantalla. |

### GPT-06 — Insets laterales ignorados

| | |
| --- | --- |
| **Estado** | **Corregido** con la emulación de Chromium (no es una prueba en dispositivo físico). |
| **Cambio realizado** | Tokens `--safe-left/right` (`env(safe-area-inset-*)`) y `--edge-l/r = max(gutter, inset)` en `tokens.css`. El contenedor, el encabezado, la barra de página, el campo de búsqueda, los rieles, las filas de chips y miniaturas, la ficha, la franja del héroe, la barra de compra y la de pago, el dock, el *toast*, los cajones (el contenido se aparta del recorte y el color del panel lo cubre), las hojas y los diálogos usan esos bordes; las filas a sangre deshacen exactamente el borde del contenedor. La cuadrícula de listados a sangre arranca en el inset (`margin-inline: inset − borde`, como el `SliverSafeArea` de la app). Las fotos y los fondos de barra siguen llegando al borde; texto y controles no. También el enlace de salto (aparecía en `left: 12px`, bajo el recorte). |
| **Reproducción antes → después** | CDP `Emulation.setSafeAreaInsetsOverride` 44 px a cada lado y 21 px abajo. **667×375:** primera tarjeta de la colección y de la búsqueda en x = 0, ancho 327,5 → x = **44**, ancho **283,5** (dos columnas de 283,5 que acaban en 623); elementos fuera de la región segura en los selectores del informe: Inicio 4, colección 4, ficha 5, bolsa 4, búsqueda 3 → 0. **812×375:** primera tarjeta en x = 32 → **44**; 3, 4, 4, 3, 1 → 0. Sin desbordamiento horizontal en ninguna. |
| **Prueba y captura** | 7 controles `GPT-06` (base 2/7 —sin inset nada se mueve; el indicador inferior ya existía—, corregida 7/7): un barrido de **todos** los controles y textos de ocho páginas (Inicio, colección, ficha, bolsa, búsqueda, favoritos, cuenta, mayoreo) a 667×375 y 812×375; la cuadrícula entre los insets (primera tarjeta en 44, columnas iguales, última tarjeta de la fila acaba en 623 y 768); sin insets nada se mueve (tarjeta en x = 0 a 375 px y gutters 20 y 48); cajones, hoja de vista rápida y cajón de la bolsa con los insets; el indicador inferior sigue sumándose bajo los botones. Capturas: `antes|despues/gpt-06-*-{667x375,812x375}.png`, [`revision-visual/A-667x375-insets44-*.jpg`](revision-visual/), `…812x375…`, `B-…-insets44-{menu,filtros,carrito}.jpg`, hojas `4`, `5`, `11`. |
| **Limitaciones pendientes** | La emulación no sustituye un dispositivo con muesca (Safari iOS, Android con recorte). El barrido deja pasar, por diseño, la tarjeta asomada de un riel que corre bajo el recorte al seguir desplazándose; en reposo no la hay. |

## 3. Hallazgo adicional A1 y defectos propios que las pruebas destaparon

**A1 — foco de teclado en contenedores con desplazamiento horizontal** (encontrado al medir GPT-01). En un riel de
Inicio, el `Tab` sobre la tercera tarjeta la dejaba en `left: 326` de 390 px (el riel con *snap* obligatorio se
repliega) y las filas de chips y miniaturas dejaban el elemento enfocado a medias fuera de la pantalla (“Crossbodys”
280…423 de 390; la miniatura 6, 340…396). `src/lib/scrollers.js` lleva el elemento a la vista en `focusin` con
`:focus-visible` (a su posición de *snap* si el contenedor la tiene; si no, lo mínimo que libera
`scroll-padding-inline`), y las filas de chips, miniaturas y la fila de categorías de tablet declaran su
`scroll-padding-inline`. 2 controles `A1` (base 0/2, corregida 2/2) y 8 pruebas unitarias del cálculo.

Defectos que las propias pruebas y la revisión visual encontraron en mi primera versión, corregidos antes de cerrar:

| Hallazgo | Causa | Corrección |
| --- | --- | --- |
| La reserva inferior no seguía a un indicador de inicio que cambiaba con la página ya cargada (dock 90 → 124 px, reserva 106 → 106) | `ResizeObserver` mira la caja de contenido; el dock crece por su *padding* | Observar la caja de borde |
| La bolsa en horizontal dejaba 164 px (cabecera de 138 + barra de pago de 73 fijas) | La regla de poca altura sólo valía < 768 px de ancho | La regla vale < 1024 px de ancho |
| El enlace de salto aparecía bajo el recorte | `left: 12px` | `left: max(12px, inset)` |
| Chips y miniaturas quedaban a medias (ver A1) | El navegador no revela el elemento enfocado en un contenedor horizontal | `scrollers.js` |

Errores del guion (no del producto), también corregidos: la sonda trataba un vecino estático como si tapara el
anillo (sólo cuenta una barra fija o *sticky*), exigía lo imposible a un elemento más alto que el espacio libre, y tres
pruebas leían el estado antes de que se aplicara una hoja de estilos, esperaban que Adelante recorriera dos entradas
de golpe o no esperaban a que volvieran los resultados.

## 4. Regresión visual: lo que no debía cambiar, no cambió

[`comparar-pixeles.mjs`](comparar-pixeles.mjs) captura las mismas páginas con la base (A) y la corregida (B) y compara
píxel a píxel, sin tolerancia, en el navegador: 16 rutas (Inicio, colección, colección con título largo, ficha, búsqueda
vacía/con resultados/sin resultados, bolsa con líneas y vacía, favoritos, cuenta, mayoreo, contacto, historia, política,
404) × 8 viewports (320×568, 360×800, 375×812, 390×844, 440×956, 768×1024, 1024×768, 1440×900) × 3 posiciones
(inicio, mitad, final) = **384 capturas: 378 idénticas**. Las 6 distintas
([`comparacion-pixeles/`](comparacion-pixeles/), [`logs/comparacion-pixeles.log`](logs/comparacion-pixeles.log)) difieren en 1 a 4
píxeles, en cada uno por **un solo nivel de gris (1 de 255 por canal)**, y son siempre de las dos páginas de estado vacío
(bolsa vacía y 404). **Control:** la base comparada consigo misma en esas dos rutas y los 8 viewports da 7 capturas
distintas de 1 a 4 píxeles y también de 1/255 como máximo
([`comparacion-pixeles-control-base/`](comparacion-pixeles-control-base/)): es ruido de ráster, no un cambio.

Las fotos se ocultan antes de capturar (sus cajas se conservan): el navegador remuestrea una fotografía de forma
ligeramente distinta en cada carga —dos cargas de la misma versión difieren unos niveles en la textura de un bolso—, lo
que no dice nada del diseño. Una primera comparación con las fotos visibles lo mostró y se descartó por eso.
Lo que **sí** cambia a propósito está fuera de esta matriz: el estado de error de la búsqueda, los viewports de poca
altura, los insets y el foco de teclado.

## 5. Revisión visual (D11)

Capturas generadas con [`revision-visual.mjs`](revision-visual.mjs): [`revision-visual/`](revision-visual/) (106 JPEG +
`index.json`, 0 problemas de consola o red, 0 píxeles de desbordamiento horizontal) y 15 hojas de contacto en
[`revision-visual/hojas/`](revision-visual/hojas/). Se abrieron como imagen y se miraron:

- **Teléfonos en vertical** 320×568, 360×800, 375×812, 390×844 y 440×956: Inicio, colección, ficha, búsqueda, bolsa y cuenta.
- **Teléfonos de lado con 44 px de inset (emulación)** 667×375 y 812×375: las mismas seis páginas, el menú, los filtros y el
  cajón de la bolsa: texto y controles dentro de la región segura, fotos a sangre, primera tarjeta en x = 44.
- **Tablet y escritorio** 768×1024, 1024×768 y 1440×900: sin cambios respecto al diseño anterior.
- **Flujos a 390×844:** filtros abiertos, vista rápida con elección obligatoria, variante elegida, sugerencias de búsqueda,
  cuenta, menú y el foco de teclado en “Novedades”, “Envíos” y “Mi cuenta” (texto y anillo completos sobre el dock).
- **Poca altura** 320×200, 360×225 y 640×400: inicio y final de las cinco páginas, el cajón de filtros y el diálogo de checkout.
- **Conjuntos estándar** ([`capturas-estandar/`](capturas-estandar/), 58) y de fidelidad
  ([`capturas-fidelidad/`](capturas-fidelidad/), 26 + `metrics.json` + `comparacion.html`), ambos con `--out` explícito.

No se vio ningún defecto abierto en las capturas finales. Las revisiones anteriores a las correcciones adicionales
(sección 3) sí mostraron la bolsa de 812×375 con la barra de pago fija: está corregida y recapturada.

## 6. Totales de las ejecuciones (puerta final, 2026-10-18 18:48–19:09 CST)

| Comando | Resultado |
| --- | --- |
| `npm test` ([`logs/npm-test.log`](logs/npm-test.log)) | **49/49** (31 anteriores + 6 de la flecha + 12 de reserva y de foco en contenedores) |
| `npm run build` ([`logs/npm-build.log`](logs/npm-build.log)) | Correcto: `index.html` 1,99 kB, CSS 68,12 kB (12,75 kB gzip), JS 274,30 kB (61,87 kB gzip) |
| `npm run verify -- --out=…/evidence` ([`logs/npm-verify.log`](logs/npm-verify.log), [`evidence/verify-report.json`](evidence/verify-report.json)) | **204/204 en 424 s**: D02 10/10 · D03 35/35 · D05 6/6 · D06 8/8 · D07 5/5 · D08 3/3 · D09 44/44 · **D11 92/92** (41 de fidelidad + 51 nuevos) · D10 1/1 (sin errores de consola, de página ni de red) |
| `node verify/check-audit-fixes.mjs --url=:4401` (base) | **10/51** pasan, 41 fallan (252 s) |
| `node verify/check-audit-fixes.mjs --url=:4402` (corregida) | **51/51** (253 s) |
| `comparar-pixeles.mjs` | 378/384 idénticas; control base-contra-base 41/48 (ver sección 4) |
| `reproducciones.mjs` antes y después | [`antes/resultados-antes.json`](antes/resultados-antes.json), [`despues/resultados-despues.json`](despues/resultados-despues.json) |
| `npm run capture -- --out=…/capturas-estandar` | 58 capturas |
| `npm run capture:fidelity -- --out=…/capturas-fidelidad` | 26 capturas + `metrics.json` + `comparacion.html` |
| `revision-visual.mjs` | 106 capturas, 0 problemas |

Una instalación limpia (`npm ci`) no se repitió: las dependencias no cambiaron.

## 7. Archivos

**Prototipo (`design-prototype/`):** `src/lib/chrome.js` y `src/lib/scrollers.js` (nuevos); `src/lib/router.js`, `src/main.js`,
`src/pages/search.js`, `src/styles/{tokens,base,components,pages}.css`; `verify/check-audit-fixes.mjs` y `verify/probes.mjs`
(nuevos), `verify/run-all.mjs` (registra `--only=fixes`); `tests/unit/chrome.test.mjs` (nuevo) y
`tests/unit/navigation.test.mjs` (+6); `verify/capture-fidelity.mjs` (el comparador que escribe calcula sus enlaces relativos a
`--out`: antes suponía una carpeta hermana de la auditoría y en una carpeta anidada sus columnas «app» y «antes» salían rotas; con
la carpeta por defecto el resultado es idéntico); `README.md`. Sin cambios: `verify/check-{identity,layout,journeys,a11y,fidelity}.mjs`,
`capture.mjs`, `package.json`, dependencias.

**Documentación (`docs/web-redesign/`):** `STATUS.md`, `DESIGN_SPEC.md` (§5, §7, §8, §9), `VERIFICATION.md`
(iteración 3), `FINAL_REPORT.md`, `IMPLEMENTATION_HANDOFF.md` (§4, §10, §11) y esta carpeta.

**Evidencia nueva ([`correcciones-auditoria-gpt-2026-10-18/`](.)):** `antes/`, `despues/`, `revision-visual/`
(+ `hojas/`), `capturas-estandar/`, `capturas-fidelidad/`, `comparacion-pixeles/`, `comparacion-pixeles-control-base/`,
`evidence/`, `logs/`, `reproducciones.mjs`, `comparar-pixeles.mjs`, `revision-visual.mjs`,
`baseline-pre-correcciones.tgz` (+ `.sha256`). **Intactos:** `audit-2026-10-18/`, `audit-gpt-2026-10-18/`,
`fidelity-2026-10-18/`, `screenshots/`, `evidence/` (ningún archivo modificado después de la instantánea de las 16:51),
`docs/prompts/` (incluido el prompt original), Flutter, backend, `.claude/`. `git status --short` es idéntico al del
inicio de la sesión; no hubo commits ni pushes, no se publicó nada ni se escribió en Shopify.

## 8. Limitaciones que siguen abiertas

- Sin dispositivo físico (iOS Safari, Android Chrome), Safari ni Firefox, ni lector de pantalla: todo se midió en Chromium 155 (Brave).
- Insets: emulación CDP de 44 px laterales y 21 px inferiores, no una muesca real.
- 320×200, 360×225 y 640×400: equivalentes de reflujo en píxeles CSS, no el zoom nativo del navegador.
- Caché de retroceso/avance: sólo prueba unitaria (Playwright la desactiva).
- Doble toque en la flecha de salida: sigue saliendo de dos pantallas (comportamiento anterior, no pedido).
- Un control más alto que el espacio libre entre barras (tarjetas de una columna en 320×568) no puede mostrar sus dos extremos.
- Las demás vistas interiores del teléfono (favoritos, cuenta, mayoreo, historia, contacto, políticas, 404) siguen con el
  encabezado global, como antes; la regla de poca altura las cubre igualmente.
