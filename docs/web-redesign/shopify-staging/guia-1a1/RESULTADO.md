# Tema web ≈ guía del cliente: resultado

Rama `feat/web-guia-1a1` (worktree `.claude/worktrees/web-guia-1a1`, desde `origin/main` `d861f06`). Contrato:
[`docs/prompts/MONETTA_WEB_GUIA_1A1_PLAN_2026-10-27.md`](../../../prompts/MONETTA_WEB_GUIA_1A1_PLAN_2026-10-27.md).
Una entrada por fase. Las evidencias con láminas o fotos del owner viven en `guia-1a1/evidencia/` y `guia-1a1/refs/`,
excluidas de git (`.git/info/exclude`), porque el repo es público.

## Decisiones de la persona (27-oct)

| # | Decisión |
|---|---|
| D1–D6 | Todas como recomienda el plan: BORRADOR de 30 láminas; worktree con el delta del 22-oct como parche; colecciones automáticas de Shopify sin escribir en el admin; fotos como assets WebP en 768, 1280 y 1920 px; textos comerciales de la app de #33; commits locales por fase, sin push. |
| D7 (nueva) | El borrador `192125304866` apareció **publicado** (`live`). Se trabaja en un duplicado sin publicar, `192558366754` «Monetta guía 1a1 borrador sin publicar 2026-10-27». `192125304866` ya no se toca. |
| D8 (nueva) | Los cambios que sólo existían en el remoto se incorporan antes de rediseñar, para no perderlos. |

## P. Preparación — cerrada

**Delta del 22-oct.**
- `git diff HEAD -- storefront-theme design-system/build.mjs` de la carpeta principal: 26 archivos, aplicados con `git apply --3way`, todos limpios.
- 40 archivos nuevos del tema, tomados de `git ls-files --others`.
- El `--check` de `port-css` se aplicó sobre `tools/style-guideline-theme/port-css.mjs`, la nueva ruta en `main`.
- Docs de texto y arneses copiados. `port-css.mjs` viejo excluido.

**Scripts reapuntados.**
- `THEME_DIR` apunta al `storefront-theme/` del worktree.
- `start-theme-dev.command` y `validate.sh` calculan su raíz desde su propia ubicación.
- `DESIGN_SPEC.md`, el `README.md` y un comentario de `monetta-app-alignment.css` nombran la nueva ruta de `port-css`.
- `design-prototype/node_modules` es un enlace simbólico a la carpeta principal: `playwright-core` y `postcss`, con el mismo lockfile.

**Comprobaciones.**
- `diff -r` contra la carpeta principal: el tema es idéntico salvo 5 líneas, todas con la ruta de `port-css`.
- `node design-system/build.mjs --check` pasa, con los 22 pares de contraste.
- `node tools/style-guideline-theme/port-css.mjs --check` pasa. Control negativo: se añade un byte a `monetta-tokens.css` y sale `exit 1`, con `stale … monetta-tokens.css`.
- `./bin/check_no_secrets.sh` pasa.
- `THEME.env` no tiene secretos: sólo tienda, ID, nombre y ruta.

**Commit.** `80df3810`.

**Referencias en `guia-1a1/refs/`** (107 MB, fuera de git):
- `slides/`: `borrador-ref/` y `borrador.pdf`;
- `app/`: `captures-final/`, 19 capturas de la app de #33;
- `owner/`: los originales del owner;
- `asset-map.txt`.

### Incidente: el borrador estaba publicado

`shopify theme list` del 27-oct, a las 18:52 UTC:
- `192125304866` aparecía con rol **`live`**;
- el tema vivo anterior, `189719183394` («monetta-production-copy-2026-08-21»), aparecía como `unpublished`.

La tienda sigue detrás de la contraseña: `/` redirige con 302 a `/password`. Esta sesión no publicó nada.
Shopify no expone la fecha de publicación. Los registros de las sesiones de Claude Code la acotan:
- la última vez que una sesión vio `192125304866` como `unpublished` fue el 22-oct a las 22:03 UTC, en la pasada del 22-oct;
- la primera vez que se vio `live` fue el 27-oct a las 18:52 UTC, en esta sesión.

Ninguna sesión de Claude Code ejecutó la publicación ni las ediciones del remoto descritas abajo.

| Paso | Resultado |
|---|---|
| Respaldo del remoto antes de cualquier escritura (sólo lectura) | `evidencia/baseline/remote-20261027T185305Z.tgz`<br>SHA-256 `c7c567639bf856038c5f3b2c9c0043bb9f2b53180c05a8805ea27011e1c1987d`<br>Manifiesto de 657 archivos |
| Remoto contra el worktree | 19 archivos distintos:<br>• los 4 comentarios de `port-css`;<br>• 10 JSON que sólo cambian de formato;<br>• 5 con cambios reales que no existen en ninguna rama ni carpeta local (ver abajo). |
| Duplicado (con autorización) | `shopify theme duplicate --theme 192125304866`, que creó `192558366754` como `unpublished`. Fue la única escritura en la tienda. |
| Respaldo del duplicado | `evidencia/baseline/draft-192558366754-20261027T192637Z.tgz`<br>SHA-256 `6ad03dbbaafe08bada2c4050876d8f5f9f284a6920e5b374f1c87f6f213e6b49`<br>Su manifiesto es idéntico al del original: 657 archivos, byte a byte. |
| Verificación de `theme-push.sh` | Con `192558366754` responde `unpublished` y el nombre coincide: OK.<br>Control negativo con `192125304866`: aborta con `role=live`. |

**Cambios recuperados del remoto** (commit `da3333d0`):
- hero del inicio v2–v4: buscador dentro del banner, CTA, panel opcional y aparición al hacer scroll;
- fila de categorías estilo monetta.mx en el header del inicio;
- línea de pagos en el footer;
- orden de secciones del inicio puesto en el editor.

Su CSS estaba añadido a mano al final de `monetta-pages.css`, que es una hoja generada. Pasó sin cambios a `assets/monetta-home-22oct.css`, que carga justo después de ella. Así `port-css --check` sigue en verde y la cascada es la misma.

**Worktree contra el duplicado** (lo que `theme dev` subirá al arrancar):
- los 4 comentarios de `port-css`;
- el bloque CSS movido a `monetta-home-22oct.css`, con su enlace en `monetta-head.liquid`;
- 10 JSON que sólo cambian de formato.

Vista previa del borrador de trabajo: <https://monetta-staging.myshopify.com/?preview_theme_id=192558366754>.

## F0. Línea base, sin tocar el tema — cerrada

**Rol.** `192558366754` sigue `unpublished` antes y después de la sincronización inicial de `theme dev`. `192125304866` sigue `live` y esta sesión no lo tocó.

**Respaldo.** Hecho en P, antes de la primera escritura, con SHA-256 (ver arriba).

**Arnés** (cambios sólo en scripts; el tema no se tocó en F0):

| Cambio | Por qué |
|---|---|
| `scripts/e2e/journey.mjs`: espera a que el `continue()` retenido termine antes del `unroute`. | El 22-oct los 4 journeys se caían con `route.continue: Route is already handled!`: el `unroute` marcaba la ruta como resuelta mientras el handler seguía en curso. Ahora corren completos. |
| `scripts/e2e/lib.mjs`: acepta `MONETTA_RUNS_DIR`. | Las corridas de esta pasada van a `guia-1a1/evidencia/runs/`, fuera de git, y no tocan el `RUNS.md` histórico. |
| `design-language-2026-10-22/scripts/theme-check-diff.mjs`: los hallazgos se identifican por su ruta dentro de `storefront-theme/`. | La línea base se tomó en la carpeta principal. Con rutas absolutas, los 243 hallazgos salían a la vez como «nuevos» y «desaparecidos». |
| `scripts/e2e/layout.mjs`: el título de recomendaciones en teléfono ahora se espera como título de sección (Playfair 400, 23 px). | Antes esperaba Inter 17/600, que es la especificación anterior al 22-oct (DESIGN_SPEC §3). Probado en ambos sentidos: con Playfair 23/400 pasa y con Inter 17/600 falla. |
| `scripts/e2e/regressions.mjs` P8: un título de menú sin `lang` sólo falla si sigue siendo uno de los títulos en inglés que Shopify trae por defecto. | Desde el 22-oct el tema traduce esos títulos a «Inicio», «Catálogo» y «Contacto». Probado: el estado actual pasa; «Home» sin `lang` falla, y el botón de pago sin `lang` también falla. |
| Nuevos: `guia-1a1/scripts/validate.sh`, `guia-capture.mjs` y `guia-sheet.mjs`. | Secuencia de validación, capturas por lámina y hojas comparativas de esta pasada. |

**Validación «antes»** (`guia-1a1/scripts/validate.sh f0-antes`, sobre `f44c678`, con el tema igual al commit):

| Paso | Resultado | Clasificación |
|---|---|---|
| `build.mjs --check`, `port-css --check` | Pasan | — |
| Theme Check | 187 errores y 64 avisos, 0 introducidos | Línea base del plan confirmada (tras corregir la clave). |
| `checks.mjs --flows` (22-oct) | 330/330 | — |
| Journeys 768×1024, 1024×768, 1440×900 | 55/55, 55/55, 54/54 | Antes no terminaban (falla del arnés). |
| Journey 390×844 | 57/58: «add: Esc closes the sheet and returns focus» | **Defecto real del tema, anterior** (ya fallaba el 22-oct). En teléfono, el botón que se pulsa es el de la barra de compra, que está fuera del `<form>`. `monetta-product.js` pasa como `trigger` el primer `[data-add]` dentro del form, que en teléfono está oculto, así que el foco no vuelve a ningún lado. **Se corrige en F4.** La falla de «Forward tras la flecha de regreso» del 22-oct no se repitió en ninguno de los 4 journeys. |
| axe, movimiento, navegación | 18/18, 4/4, 31/31 | — |
| Teclado | 147/150: en el inicio, a 320, 375 y 440, «Totes» y «De hombro» no pintan el lado izquierdo del anillo de foco | **Defecto real, anterior** (igual el 22-oct). El riel recorta el anillo del primer elemento. Esa fila se rehace en F2, donde la comprobación debe pasar. |
| Layout | 214/219: título de recomendaciones | **Comprobación desfasada**; corregida (ver arriba). |
| Regresiones | 122/123: P8 | **Comprobación desfasada**; corregida. El chequeo de salud del proxy, que fallaba el 22-oct, ahora pasa. |

**Datos de staging que fijan D3:**
- **Marcas** (vendor): Guess 92, Coach 34, Michael Kors 22 y Steve Madden 7. No hay productos de Tory Burch, Kate Spade ni Marc Jacobs, y `/collections/vendors?q=` devuelve 404 para ellas.
- **Tipos de producto**: inconsistentes («Bolsa Tote», «Cartera», «Reloj», 34 vacíos).
- **Etiquetas**: consistentes (Tote 19, Shoulder 15, Crossbody 58, Satchel 27, Carteras 15, Reloj 19).
- **Rutas elegidas** (decisión reversible):
  - marcas: `/collections/vendors?q=<Marca>`;
  - categorías: `/collections/all/<etiqueta>`, el filtro por etiqueta de Shopify, verificado con conteos reales.
- **Páginas**: sólo existe `/pages/contact`. Mayoreo y Rewards se construyen como plantillas de página. En staging se ven con `?view=` sobre una página existente; crear las páginas queda para el owner.

**Capturas «antes»** (`guia-capture.mjs`, 21 rutas × 390 y 1440) y hojas comparativas en `evidencia/sheets/f0-antes/`, con las columnas lámina | 390 | 1440 | app.
- Única captura fallida: el menú a 1440, porque el header de escritorio no tiene botón de menú. Lo pide F2.
- `/collections/vendors?q=Tory Burch` responde 404.
- Arreglo del capturador: la espera de imágenes tiene un tope de 8 s, porque las imágenes `lazy` de los rieles horizontales nunca cargan fuera de pantalla.

## F1. Base visual — cerrada (`65e6fb0`)

**Qué entra en el tema**
- **Fuentes:** Cormorant Garamond (300, 300 itálica, 400, 400 itálica y 500) y Mrs Saint Delafield, en WOFF2 convertido con `wawoff2`, con sus avisos OFL. Salen de la rama de #33, nunca del PPTX.
- **Tokens del lado de Shopify** en `monetta-guia.css`:
  - `--font-guide-serif` y `--font-guide-script`;
  - la pastilla dorada `#cdb48d` con texto `#2b2118`;
  - el velo crema `#FBF6EE` de `GuideScrim`.

  El manifiesto compartido no se tocó.
- **Imágenes:**
  - los 21 iconos en WebP con transparencia;
  - las 23 fotos del owner en WebP a 768, 1280 y 1920 px, hechas con `cwebp` (ffmpeg no trae codificador WebP);
  - 3 imágenes fijas de la app a su tamaño propio, sin ampliar.

  Suman unos 3 MB. Las fotos derivadas sí van al tema y a git, como ya lo hizo la app en #33 (con JPEG de 1290 px). Los originales del owner se quedan fuera.
- **Componentes:** `GuidePillButton`, `GuideHero` con su velo, `ClientGuideServices`, y VER PRODUCTO en la rejilla de colección, como pastilla visual dentro del único enlace de la tarjeta. Snippets: `monetta-guia-photo`, `-icon`, `-hero` y `-services`.

**Comprobaciones**

| Comprobación | Antes (árbol F0) | Después |
|---|---|---|
| `guia-checks` F1: tokens, 6 caras cargadas, fuentes medidas con CDP, 99 archivos servidos, VER PRODUCTO a 320, 390, 768, 1024 y 1440 | 7/34. Pasan sólo los resguardos: sin desbordes, sin VER PRODUCTO en rieles ni en búsqueda. | **34/34** |
| `checks.mjs --flows`, axe, movimiento, navegación | — | 330/330, 18/18, 4/4, 31/31 |
| Journeys | — | 768, 1024 y 1440 completos; 390 con 57/58, la falla conocida de F4 |
| Layout, regresiones | — | 219/219, 123/123, en la corrida repetida tras reiniciar el proxy |
| Teclado | — | 139/145, clasificado así:<br>• 2 fallas son el defecto conocido de «Totes» (se corrige en F2);<br>• 3 fallas a 375×812 (el enlace de salto medido fuera de pantalla) y 1 cierre del navegador a 812×375 no se repitieron al correr esos dos tamaños aislados. Se clasifican como inestabilidad del entorno. |
| Theme Check | 187 errores y 64 avisos | Sin errores nuevos. Hay 4 avisos `OrphanedSnippet` por componentes que todavía no se usan; F2 y F3 los conectan. |

**Incidentes**
- Un error de sintaxis Liquid mío, en un archivo nuevo de F2 sin usar (filtro dentro de un `for`), hizo que `theme dev` sirviera «Failed to Upload Theme Files» en todas las rutas. Esa corrida se descartó.
  - Desde entonces, `guia-1a1/scripts/preflight.mjs` corre Theme Check sobre una copia del tema antes de escribir en `storefront-theme/`. Probado: el archivo defectuoso da `exit 1`.
- La sesión del proxy caducó a los ~90 minutos (401). La persona la reinició.

**Hoja comparativa:** `evidencia/sheets/f1/`. En 06 Coach y 14 Totes, VER PRODUCTO ya aparece como en la lámina y en la app, en ambos anchos. El hero, las pastillas y el conteo llegan en F3.

## F2. Inicio, header, menú, barra inferior y pie — cerrada

**Qué cambió**
- **Inicio** (`templates/index.json`, sección `monetta-guia-home` con un módulo por sección, reordenables en el editor), en el orden de la app de #33:
  1. carrusel de 3 fotos del owner: «Compra *fácil* desde México», «NUEVA COLECCIÓN · Un paraíso de marcas por descubrir.» y «PERFUMES · Descubre nuestra selección de fragancias originales». Desliza con snap, tiene puntos y, desde 1024 px, flechas; sin autoplay, como la app;
  2. «Compra por estilo» con los 5 iconos de la guía;
  3. «Tus marcas favoritas»: las 8 de la guía, en su orden, sólo las que la tienda vende. En staging salen Coach, Guess, Michael Kors y Steve Madden;
  4. «Nueva colección» y 5. «Lo más buscado», con los rieles del tema;
  6. «PRECIOS DE *mayoreo* · A partir de 3 piezas · CONOCE MÁS»;
  7. los 4 servicios;
  8. «REGÍSTRATE · Consulta tus pedidos y datos de compra · REGISTRARME AHORA · Pagos seguros con Shopify.».

  Salen del inicio el hero del 22-oct, Colecciones, Más sobre Monetta, Nuestras redes y Experiencias. Siguen disponibles como secciones del tema.
- **Header:**
  - quité la fila con emoji del 22-oct;
  - la navegación de tablet y escritorio es la de la guía: Bolsas, Carteras, Relojes, Perfumes, Marcas y Mayoreo;
  - el botón de menú queda visible también en escritorio, y abre el mismo cajón;
  - los menús de Shopify (en inglés) ya no alimentan el header.
- **Cajón** (lámina 30):
  - identidad: Invitado / Inicia sesión, o el nombre y el correo del cliente;
  - Bolsas, Carteras, Relojes, Perfumes, Todas las marcas y Guardados. Guardados es propio de la web, porque la lista vive en el navegador;
  - el banner «Comparte y gana · VER CATÁLOGO»;
  - Contacto por WhatsApp y TikTok, Instagram y Facebook, con las URL de la app.
- **Barra inferior:** Inicio · Categorías (→ `/collections`) · Carrito · Cuenta.
- **Pie:** el logotipo, Ayuda (menú de la tienda), Información (sus políticas), Síguenos y «© 2026 Monetta Staging. Todos los derechos reservados.». El texto de marca y el botón de WhatsApp quedan como ajustes, pero no se muestran.
- **`snippets/monetta-guia-url.liquid`:** un solo lugar decide cada destino. Si el owner crea la colección o la página, la usa; si no, recurre a la lista automática de Shopify.

**Comprobaciones**

| Comprobación | Antes (árbol F1) | Después |
|---|---|---|
| `guia-checks` F2: orden de módulos, textos de la app, fotos, fuentes medidas («fácil» y «mayoreo» en Mrs Saint Delafield), flechas, estilos, marcas, pastilla, servicios, regístrate, header, barra inferior, pie y cajón, a 390 y 1440 (sin desbordes de 320 a 1440) | 6/31, más 1 error al no encontrar las flechas | **F1 + F2: 88/88** |
| Validación completa | — | `checks.mjs` 315/315, layout 219/219, regresiones 123/123, movimiento 4/4, navegación 31/31, journeys a 768, 1024 y 1440 completos |
| axe | — | Falló en la primera corrida (ver abajo). Tras la corrección: 18/18. |
| Teclado | En F0, «Totes» y «De hombro» fallaban a 320, 375 y 440 | Con la fila nueva ese defecto ya no existe. Una falla nueva a 320 (ver abajo); tras la corrección, el inicio a 320, 375 y 440 da 9/9. |
| Journey 390 | 57/58 | 57/58: sólo la falla conocida de F4 |

**Encontrado y corregido en la validación**
1. **axe crítica** `aria-required-children`: el carrusel era una lista con hijos `role="group"`. Ahora usa `div`.
2. **Teclado a 320:** una tarjeta de marca de 1.7 con `min-height: 48px` toma un ancho mínimo de 81.6 px a través de la proporción, y la tarjeta siguiente le tapaba el anillo. Ahora la altura sigue a la columna, con un mínimo de 48 px. La comprobación nueva («no se enciman y miden al menos 48 px») falla con el CSS anterior inyectado.
3. **Iconos sociales del pie en columna:** la lista de `.footer-col` le ganaba a la fila. Corregido, con su comprobación y su control negativo.
4. **«marcaspor»:** el `<br>` sin espacio unía las palabras en el texto accesible.
5. **Arnés:** el journey hacía clic en el primer «Ver todo» del inicio, que ahora es el de «Compra por estilo». Apunta al de «Nueva colección».

**Theme Check:** sin errores nuevos. Avisos `OrphanedSnippet`:
- `monetta-guia-hero` (lo usa F3);
- `monetta-menu-icon`, que quedó sin uso con el cajón nuevo y se elimina en F3.

**Hojas comparativas:** `evidencia/sheets/f2/` (03 Inicio y 30 Menú) y `evidencia/sheets/f2-final/`.

## F3. Colecciones, Categorías y Búsqueda — cerrada

**Qué cambió**
- **Colecciones** (láminas 06–20):
  - en teléfono se ve el header de la guía, no la barra de página;
  - la foto de la guía va a sangre completa. El título es el `h1`, en mayúsculas: rectas para marca, itálica ligera para silueta o categoría. La foto se elige como en `guideCollectionPhoto`: marca (lista de vendor), luego silueta (etiqueta), luego categoría (tipo de producto o colección propia);
  - las pastillas: botón de filtros, Bolsas, Carteras, Accesorios, Relojes y Más, con la activa en café;
  - «N productos» y «Ordenar por»;
  - la rejilla con VER PRODUCTO.

  En escritorio el hero baja a 3.4:1, con un máximo de 420 px, para que la primera fila de productos quede en la primera pantalla. Una lista sin foto de la guía conserva su título.
- **Categorías** (lámina 29), sección `monetta-guia-categories`:
  - título y línea de la app;
  - «Colecciones» con los 7 iconos, en 3, 4 o 7 columnas según el ancho;
  - «Marcas», sólo las que vende la tienda.

  Se quitó de esa página la lista de colecciones del comerciante (en staging: «Automated Collection», «Home page», «Hydrogen»).
- **Búsqueda** (lámina 05):
  - «Búsquedas recientes»: las últimas 5, guardadas sólo en el navegador, cada una con botón para quitarla y anuncio del cambio;
  - «Sugerencias»: Bolsas, Carteras, Relojes y Perfumes;
  - los resultados de Shopify.
- Se eliminó `monetta-menu-icon.liquid`, que quedó sin uso.

**Comprobaciones**

| Comprobación | Antes (árbol F2) | Después |
|---|---|---|
| `guia-checks` F3: hero, `h1` único, mayúsculas, recta o itálica, pastillas y la activa, botón de filtros de 48 px, conteo y orden, header en teléfono, título medido en Cormorant, Categorías, búsqueda y recientes (quitar uno lo borra del navegador) | 4/31, más 1 error | **F1–F3: 149/149** |
| Validación completa | — | `checks.mjs` 315/315, teclado **150/150** (sin ningún defecto de foco), axe 18/18, regresiones 123/123, movimiento 4/4, navegación 31/31, journeys a 768, 1024 y 1440 completos, Theme Check sin hallazgos nuevos |
| Layout | — | 223/223, tras adaptar el arnés (abajo) |
| Journey 390 | — | 58/59: sólo la falla conocida de F4 |

**Arnés adaptado al cambio de diseño**
- `layout.mjs`: en una colección, la barra fija ahora es el header en todos los anchos. Las pruebas de la barra de página (76 px, y que crezca con un título largo) se movieron a la búsqueda, que la conserva.
- `journey.mjs`: la flecha de la barra de página se prueba en la búsqueda. Se llega con un clic en un enlace, porque una URL escrita empieza la historia en 0.

**Incidente:** `list-collections.json` se subió antes que su sección nueva, y el proxy mostró «Failed to Upload» en todas las rutas. Theme Check no puede verlo; se resolvió volviendo a guardar la plantilla.

**Diferencias que quedan**
- En teléfono, la búsqueda conserva su barra de página («← Buscar» con filtros) en lugar del header de la lámina: ahí vive el botón de filtros.
- Los resultados van en 2 columnas, donde la lámina muestra una vista previa de 3.
- Las pastillas navegan entre categorías. Para filtrar dentro de una marca hacen falta filtros por tipo o etiqueta en Search & Discovery (owner).
- Tory Burch, Kate Spade y Marc Jacobs no tienen productos en staging: su página es la 404 de la tienda.

**Hojas comparativas:** `evidencia/sheets/f3/` (05, 06–09, 14, 15, 17, 19, 20 y 29).

## F4. Vista rápida, Producto y Carrito — cerrada

**Qué cambió**
- **Vista rápida** (lámina 12), sección `monetta-quick-view` servida por la Section Rendering API (`/products/<handle>?section_id=monetta-quick-view`):
  - se abre con el «+» de una tarjeta cuando la pieza tiene varias variantes, como `quick_add_button.dart` de la app. Con una sola variante, el «+» sigue agregando directo;
  - hoja inferior en teléfono, diálogo centrado desde 768 px;
  - foto con hasta 4 miniaturas, marca, nombre, precio («Desde» si varía), opciones como pastillas, «Agregar a bolsa» y «Ver producto»;
  - nada se agrega hasta elegir una variante disponible (el `requireChoice` de la app). Un aviso dice por qué el botón está apagado;
  - si la sección no responde, el «+» lleva a la página del producto.
- **Producto** (lámina 13):
  - la fila de confianza de la app: Entrega estimada · 3 a 5 días, Productos originales · Garantía de autenticidad, Pago seguro · Compra con confianza;
  - «Agregar a bolsa» en el formulario y en la barra de compra, como la app (antes «Agregar al carrito»).
- **Defecto anterior corregido** (F0, «Esc cierra la bolsa y devuelve el foco»): en teléfono el foco vuelve al botón que se pulsó, el de la barra de compra, y no al del formulario, que está oculto.
- **Carrito:** sin cambios de diseño. La lámina 28 es la confirmación «¡Gracias por tu compra!», que es la página de gracias de Shopify (fuera del tema). «Mi bolsa» ya sigue el estilo de la app desde el 22-oct (hoja `evidencia/sheets/f4-28/`).
- `monetta-guia.js` ya trae el «Copiar enlace» de «Comparte y gana», y `guia-checks.mjs` las comprobaciones de F5. Ninguno de los dos actúa hasta F5.

**Defecto anterior: la flecha de regreso y Forward** (la falla del journey a 390 que el 22-oct quedó sin clasificar)
- **Causa** (diagnóstico con CDP en `evidencia/runs/`, script en el scratchpad de la sesión):
  - la flecha de la barra de página llama a `history.go(-pasos)` y deja un respaldo: si a los 500 ms la página no cambió, asigna la URL padre;
  - en el navegador de pruebas no hay bfcache (`BackForwardCacheDisabledByCommandLine`) y Shopify manda `Cache-Control: no-store`, así que volver al inicio siempre va a la red. Esa navegación tardó ~450 ms;
  - cuando tarda más de 500 ms, el respaldo asigna «/» a media navegación. Esa entrada nueva borra la historia hacia adelante y Forward se queda en el inicio. A una clienta con datos móviles lentos le pasa lo mismo.
  - Por eso fallaba a veces (22-oct) y dos de dos veces en F4, con el proxy recién reiniciado y más lento.
- **Prueba** (`scripts/e2e/journey.mjs`): el inicio responde 1.2 s después de pulsar la flecha. Comprobación nueva: «en red lenta la flecha regresa sin crear una entrada nueva».
  - Árbol anterior: falla (`historyBefore 10`, `historyAfter 11`, 2 peticiones al inicio) y Forward termina en `/`.
- **Corrección** (`monetta-core.js`): al empezar la navegación hacia atrás, el navegador dispara `beforeunload` (a los ~46 ms en el diagnóstico); ese evento retira el respaldo. El listener sólo existe mientras el respaldo está armado, así que no afecta la bfcache.
  - Después: historial 10 → 10, una sola petición y Forward vuelve a la búsqueda.
- **Resguardo:** otra comprobación nueva confirma que el respaldo sigue funcionando cuando `history.go` no tiene adónde ir (un estado que nombra más entradas de las que tiene la pestaña). Pasa en ambos árboles; existe para que la corrección no lo apague.

**Comprobaciones**

| Comprobación | Antes (árbol F3) | Después |
|---|---|---|
| `guia-checks` F4 a 390 y 1440: «Agregar a bolsa», fila de confianza, foco tras la barra de compra, «+» de varias variantes, vista rápida (contenido, hoja o diálogo, nada sin elegir, la variante elegida llega al carrito de Shopify, Esc devuelve el foco al «+») | 0/4 y error: no existe `[data-quick-view]` | **F1–F4: 168/168** |
| Validación completa (`validation/f4/`) | — | `checks.mjs` 315/315, axe 18/18, movimiento 4/4, navegación 31/31, journeys a 768, 1024 y 1440 completos, Theme Check sin hallazgos nuevos (187 errores y 64 avisos) |
| Teclado, layout, regresiones | — | 150/150, 223/223, 123/123 (tras reiniciar el proxy, que caducó a media corrida) |
| Journey 390 | 57/58 (foco) | Antes de la corrección: 58/59, sólo la flecha. Después: **61/61**, con las 2 comprobaciones nuevas |
| `build.mjs --check`, `port-css --check`, `check_no_secrets.sh` | — | Pasan |

**Hojas comparativas:** `evidencia/sheets/f4/` (12 y 13) y `evidencia/sheets/f4-28/` (28).

## F5. Mayoreo, Contacto, Monetta Rewards y Comparte y gana, y Cuenta — cerrada

**Qué cambió**
- **Plantillas nuevas** `page.guia-mayoreo`, `page.guia-contacto` y `page.guia-rewards`, todas sobre la sección `monetta-guia-page`. Las plantillas del owner (`page.contact`, `page.mayoreo`, `page.como-vender`) no se tocaron.
- **Mayoreo** (láminas 21–22, `wholesale_screen.dart`):
  - hero «MAYOREO · Obtén precios especiales … *marcas favoritas*»;
  - «¿Cómo comprar?» en los 3 pasos de la app (mínimo 3 piezas; apartado de $800 por 20 días);
  - banners «BOLSOS Y CARTERAS» y «PERFUMES» con VER CATÁLOGO;
  - los servicios de mayoreo, que abren con «Envío gratis · En compras mayores a $1,999 MXN»;
  - «¿Tienes dudas? Escríbenos por WhatsApp» sobre la foto de bolsos de mayoreo, con el velo crema y la línea dorada de la app y su mensaje de WhatsApp;
  - la nota «Precios del catálogo de menudeo; cotización de mayoreo pendiente.» y un riel de productos.
- **Contacto** (lámina 27, `contact_screen.dart`):
  - hero «Tu boutique y proveedor de *confianza.*», con el título en renglones parejos (`text-wrap: balance`);
  - Contáctanos: WhatsApp, Grupo 1, Grupo 2, Grupo de Facebook y Mayoreo por WhatsApp, con las URL de la app;
  - Síguenos en redes;
  - **«Escríbenos»**, el formulario de contacto de Shopify, como pide el plan (§5). Es propio de la web, porque la app no lo tiene, y su texto («Déjanos tu mensaje y te responderemos por correo.») no viene de la app. Las pruebas lo revisan pero nunca lo envían, porque un envío le llegaría por correo a la tienda.
- **Monetta Rewards y Comparte y gana** (láminas 25–26, `rewards_guide_screen.dart` y `rewards_share_screen.dart`), en una sola página:
  - «Monetta Rewards · Tus compras, acumulas puntos.» y el estado de la app sin contrato: «Monetta Rewards aún no está disponible». No hay saldo, puntaje ni nivel, porque no hay backend;
  - «Cómo ganar puntos» y «Canjear puntos» con las filas de la app;
  - el botón «Comparte y gana», que baja a su sección. En la app abre otra pantalla;
  - el banner, la línea de la app y «Puntos por compartir: Pendiente de contrato.»;
  - «Copiar enlace de catálogo de bolsos / de perfumes» con los listados reales de la tienda y el aviso «Enlace copiado», como la app;
  - «Compartir enlace» abre el menú de compartir del sistema (`navigator.share`, el `Share.share` de la app) y sólo aparece donde el navegador lo tiene.
- **Cajón:** el banner «Comparte y gana · VER CATÁLOGO» lleva a Comparte y gana, como el banner de la cuenta en la app (`account_screen.dart`). Antes llevaba al catálogo completo.
- **Cuenta:** la barra inferior y el header llevan a `/account` de Shopify; las pantallas de Mis pedidos y Mi cuenta (láminas 23–24) son de Shopify y quedan fuera del tema.
- **Destinos** (`monetta-guia-url`): si el owner crea la página y le asigna la plantilla de la guía, el enlace va directo; mientras tanto, usa `?view=guia-*` sobre `/pages/contact`, la única página que existe.

**Comprobaciones**

| Comprobación | Antes | Después |
|---|---|---|
| `guia-checks` F5 a 320, 390, 768, 1024 y 1440 (sin desbordes) y a 390 y 1440 (contenido): textos de la app, foto y velo de «¿Tienes dudas?», servicios, pasos, banners, filas de contacto de 48 px, «confianza.» medida en Mrs Saint Delafield, Rewards sin saldo inventado, enlaces reales, copiar al portapapeles, compartir, cajón y Cuenta | Árbol F4: 14 de contenido fallan y 6 de desbordes pasan | **57/57** |
| Ajustes tras las hojas (título de Contacto, «Enlace copiado», compartir, formulario) | Con los archivos previos: 7 fallas y luego 2 del formulario. A 390, el título ya se partía bien. | Pasan |
| `guia-checks` F1–F5 completo | — | 223/223 (antes del formulario) y F5 57/57 después |
| Validación completa (`validation/f5/`) | — | `checks.mjs` 315/315, journeys 61/61, 55/55, 55/55 y 54/54, movimiento 4/4, navegación 31/31, teclado 150/150, regresiones 123/123, Theme Check sin hallazgos nuevos (187 errores y 64 avisos) |
| axe | — | **28/28**. Ahora también revisa Categorías, Mayoreo, Contacto (con el formulario), Rewards y la vista rápida abierta, a 375 y 1440. |
| Layout | — | 221/222: «1024×768: el riel de recomendaciones de Shopify no apareció». Repetido sólo a 1024×768 dos veces: 10/10 con el riel de 8 tarjetas. Se clasifica como demora de la API de recomendaciones de Shopify. F5 no toca la página de producto. |
| `build.mjs --check`, `port-css --check`, `check_no_secrets.sh` | — | Pasan |

**Diferencias que quedan**
- Paso 2 de «¿Cómo comprar?»: la app usa un carrito; la web usa «+», porque el juego de iconos del tema no tiene carrito.
- Rewards: la lámina dibuja un saldo («320 puntos», «Nivel Plata»). La web, igual que la app sin contrato, no lo inventa.
- En la lámina, «Rewards» va en letra manuscrita; la app y la web lo escriben recto.

**Para el owner (sin escribir en el admin, como decidió D3):**
1. Crear las páginas Mayoreo (`/pages/mayoreo`) y Rewards (`/pages/rewards`) y asignarles las plantillas `guia-mayoreo` y `guia-rewards`.
2. Asignar `guia-contacto` a la página Contacto que ya existe.
3. Con eso los enlaces del tema van directo, sin `?view=`.

**Hojas comparativas:** `evidencia/sheets/f5/` (21, 22, 25, 26, 27 y 30), `evidencia/sheets/f5-final/` (25–27 tras los ajustes) y `evidencia/sheets/f5-form/` (27 con el formulario).

## F6. Verificación completa, comparación remota y entrega — cerrada

**Verificación final** (`validation/f6/`, `validate.sh f6` sobre `aadcd4a`, árbol limpio) — todo en verde, por primera vez en esta pasada sin ninguna falla:

| Paso | Resultado |
|---|---|
| `build.mjs --check`, `port-css --check` | Pasan |
| Theme Check | 187 errores y 64 avisos, 0 introducidos |
| `guia-checks` F1–F5 | **225/225** |
| `checks.mjs --flows` (22-oct) | 315/315 |
| Journeys 390, 768, 1024 y 1440 | 61/61, 55/55, 55/55 y 54/54 |
| axe (con las páginas de la guía y la vista rápida) | 28/28 |
| Movimiento, navegación, teclado | 4/4, 31/31, 150/150 |
| Layout, regresiones | 223/223, 123/123 |
| Capturas finales | 46 capturas (23 láminas × 390 y 1440). Sin imágenes rotas. Única respuesta no 200: Tory Burch, 404 conocida (no tiene productos en staging). |

**Comparación remota** (`evidencia/f6/remote-before-push/`, sólo lectura, 28-oct 01:31 UTC):
- `192558366754` tiene rol `unpublished` y el nombre esperado;
- remoto y worktree tienen 776 archivos cada uno, 762 idénticos byte a byte y 0 diferencias de contenido. Los otros 14 son JSON que Shopify reformatea (`equivalent: true`).

**Subida protegida: no hizo falta.** `theme dev` ya había subido cada archivo al borrador. Un `theme-push.sh` no cambiaría contenido; sólo volvería a formatear esos 14 JSON. Se omitió para no escribir en la tienda sin necesidad.

**Roles** (`shopify theme list`, 28-oct 01:32 UTC): `192558366754` sigue `unpublished`. `192125304866` sigue `live`, igual que al empezar, y esta sesión no lo tocó. Los demás temas no cambiaron.

**Hojas comparativas finales:** `evidencia/sheets/f6/` (lámina | 390 | 1440 | app, 23 láminas).

**Vista previa:** <https://monetta-staging.myshopify.com/?preview_theme_id=192558366754>. La contraseña de la tienda la escribe la persona.

**Pendiente**
- ~~**Láminas sin fase.** El mapa (§5) incluye 01 Bienvenida (página de contraseña) y 04 «Rastrea tu pedido», pero ninguna fase de §6 las asignó. Van en F7.~~ Resuelto en F7 (abajo).
- **Para el owner:**
  - crear y asignar las páginas de la guía (ver F5);
  - las 13 colecciones de marca y categoría (D3);
  - filtros por tipo o etiqueta en Search & Discovery (F3).
- **Fuera del tema:** checkout, página de gracias, cuentas de cliente (Mis pedidos, Mi cuenta) y menús del admin.
- **Push a GitHub:** sólo cuando la persona lo pida (D6). Rama local `feat/web-guia-1a1`.

## F7. Láminas 01 y 04 — cerrada

El mapa de láminas (§5 del plan) incluía dos láminas que ninguna fase de §6 tenía asignadas.

**04 «Página principal (seguimiento)»: el plan la leyó mal.**
- La lámina no es «Rastrea tu pedido». «Seguimiento» quiere decir la continuación del inicio al hacer scroll: Lo más buscado, Precios de mayoreo, servicios, Regístrate y pie.
- F2 ya lo cubre todo, así que no hay nada que construir. Se agregó su captura (`guia-capture.mjs`, lámina 04, el inicio desde «Lo más buscado») y su hoja `evidencia/sheets/f7/sheet-04.png`.
- La web no tiene rastreo de pedidos: los pedidos viven en las cuentas de Shopify.

**01 Bienvenida, en la página de contraseña** (`welcome_screen.dart`)
- **Sección nueva `monetta-guia-welcome`**, que `templates/password.json` usa en lugar de la sección `password` de Atelier. Esa sección se queda en el tema, sin usarse.
  - La foto del owner (`bienvenida-fondo`, sin bolso, como la app), el wordmark, «Un paraíso de marcas por descubrir», «BOUTIQUE ONLINE DE PRODUCTOS ORIGINALES» y «COMENZAR».
  - «COMENZAR» abre el diálogo de contraseña de Shopify con el mismo disparador que usa el pie de Atelier (`on:click="#password-form/showDialog"`).
  - Teléfono: la foto ocupa toda la pantalla, como la app. Desde 1024 px, la foto (vertical, 718 × 1280) va a la derecha y el texto a la izquierda, para no estirarla.
  - El layout de contraseña no carga las hojas de Monetta, así que la sección trae su propio CSS (`{% stylesheet %}`).
- **Página en español:**
  - `lang="es-MX"`;
  - el diálogo dice «Entra con la contraseña de la tienda», «Contraseña» y «Entrar», y en el error, «La contraseña no es correcta.»;
  - el pie dice «Esta tienda funciona con», «Entrar con contraseña» y «¿Eres la dueña o el dueño de la tienda? Inicia sesión aquí».

  Antes salía en inglés («Opening soon», «Enter using password»), porque el idioma de la tienda en staging es inglés y Atelier usa sus traducciones.
- **Alcance:** esta página sólo se ve en la vista previa del borrador.
  - **Corrección del 28-oct:** la puerta pública de staging no la pinta ningún tema. `curl https://monetta-staging.myshopify.com/password` devuelve la página genérica de Shopify («This store is password protected… Enter store password»), propia de las tiendas de desarrollo.
  - Por eso la bienvenida no se ve en la puerta de staging ni con el tema publicado. Se verá en una tienda con plan cuyo tema pinte su propia página de contraseña.

**Comprobaciones**

| Comprobación | Antes (árbol F6) | Después |
|---|---|---|
| `guia-checks` F7: sin desbordes de 320 a 1440; a 390 y 1440, textos de la app, foto, composición (pantalla completa en teléfono, mitades en escritorio), «COMENZAR» de 48 px en la primera pantalla, español sin restos en inglés, frase medida en Playfair, «COMENZAR» abre el diálogo en español, Esc lo cierra y devuelve el foco | 2/8: sólo pasan los desbordes; luego error (no existe el botón) | **21/21** |
| `guia-checks` F1–F5 + F7 | — | **246/246** |
| axe (ahora también `/password`) | — | 30/30 |
| Theme Check, `build.mjs --check`, `port-css --check`, `check_no_secrets.sh` | — | 0 hallazgos nuevos (187 errores y 64 avisos); los demás gates pasan |

El resto de la suite no visita `/password` y F7 no cambia ninguna otra página. Su última corrida completa es la de F6 (todo en verde).

**Hojas:** `evidencia/sheets/f7/` (01 y 04).

## F8. Header: buscador «liquid glass» y fuentes (pedido del 28-oct) — cerrada

**Pedido de la persona:** la barra de búsqueda del header, más tipo *liquid glass*; «Cuenta», «Carrito» y el texto del buscador con la fuente de Bolsas · Carteras · Perfumes · Marcas · Mayoreo.

**Qué cambió** (`assets/monetta-guia.css`, sólo el buscador del header; los de la página de búsqueda y la 404 siguen igual):
- **Buscador «liquid glass»:**
  - relleno blanco translúcido en degradado, con `backdrop-filter: blur(24px) saturate(180%)`;
  - doble filo: el contorno exterior sigue en `--color-border-control` (4.03:1 sobre el header, WCAG 1.4.11, como pide DESIGN_SPEC), con un filo claro por dentro;
  - brillos especulares en las esquinas superior izquierda e inferior derecha, un reflejo cálido dorado abajo y una sombra corta.
  - Enfocado conserva el anillo de tinta.
- **Fuentes:** «Cuenta», «Carrito», el placeholder y el texto escrito usan la fuente de la fila de categorías: Playfair Display, peso 500, como `--type-section-title-font`. Las etiquetas van a 14 px, como la fila. El campo se queda en 16 px para que iOS no haga zoom al enfocarlo.

**Encontrado en la validación**
- `nav.mjs`, a 768×1024 y 812×375: «ningún enlace queda bajo el desvanecido de la fila» falló en «Carteras» y «Relojes».
- **Causa:** la sombra exterior del buscador bajaba ~25 px, y entre el campo y la fila de categorías sólo hay 9. Así oscurecía el texto bajo el desvanecido.
- **Aislado con `--inject-css`** (opción nueva de `nav.mjs`): sin `backdrop-filter` sigue fallando; sin la sombra, pasa.
- **Corrección:** la sombra ahora termina dentro de esos 9 px. Después, navegación 31/31.

**Comprobaciones**

| Comprobación | Antes | Después |
|---|---|---|
| `guia-checks` F8 a 768, 1024 y 1440: Cuenta y Carrito con la familia, tamaño y peso de la fila; placeholder y texto escrito con su familia, a 16 px; Cuenta, placeholder y texto escrito medidos en Playfair con CDP (el texto del input se mide dentro de su shadow DOM de agente de usuario); vidrio (desenfoque, degradado, filo interior); contorno ≥ 3:1; anillo de tinta al enfocar | 6/18 (pasan sólo el contorno y el anillo, que son resguardos) | **18/18** |
| Validación completa (`validation/f8/`) | — | guía F1–F5 + F7 + F8 264/264, `checks.mjs` 315/315, journeys 61/61, 55/55, 55/55 y 54/54, axe 30/30, movimiento 4/4, layout 223/223, regresiones 123/123, Theme Check sin hallazgos nuevos |
| Navegación | — | 29/31 con la primera sombra; **31/31** con la sombra corta |
| Teclado | — | 150/150 con la primera sombra. Con la sombra corta, la repetición **se interrumpió** al publicar, para que la persona cerrara el proxy: 89 pasaron y 2 fallaron. Una es «Saltar al contenido» medido fuera de pantalla a 375×812; la otra, «Target page … has been closed» a 812×375, la produjo el propio corte. Es la inestabilidad del entorno ya clasificada en F1; a 375 px el buscador del header no se muestra. Las 150 no se completaron con la sombra final. |
| `build.mjs --check`, `port-css --check`, `check_no_secrets.sh` | — | Pasan |

**Arnés:** `start-theme-dev.command` ahora se niega a arrancar si el tema de `THEME.env` no está sin publicar. Con un tema publicado, `theme dev` escribiría cada archivo guardado en la tienda pública.

## Publicación en staging (28-oct, pedido de la persona)

La persona pidió publicar el tema en staging para que lo vea el owner.

| Paso | Resultado |
|---|---|
| Antes (`shopify theme list`) | `192558366754` sin publicar; `192125304866` publicado |
| Borrador contra worktree (`0514d9f`, `evidencia/f8/remote-before-publish/`) | 777 archivos de cada lado, 0 diferencias de contenido, `equivalent: true` |
| `shopify theme publish --theme 192558366754` | 28-oct a las 03:05 UTC: «is now live at https://monetta-staging.myshopify.com» |
| Después (`shopify theme list`) | **`192558366754` publicado**. `192125304866` quedó sin publicar y se puede volver a publicar. Los demás temas no cambiaron. |

- **Para el owner:** en <https://monetta-staging.myshopify.com> escribe la contraseña de la tienda en la página genérica de Shopify (la de las tiendas de desarrollo) y entra al tema nuevo. Ya no hace falta `?preview_theme_id`.
- **Nombre:** el tema todavía se llama «Monetta guía 1a1 borrador sin publicar 2026-10-27». Renombrarlo es otra escritura en la tienda; queda para cuando la persona lo pida.
- **Para seguir trabajando:** duplicar el tema publicado y apuntar `THEME.env` al duplicado. `theme-push.sh` y `start-theme-dev.command` se niegan a escribir en un tema publicado.

## Sin migas de pan (28-oct, pedido de la persona)

**Pedido:** quitar «Inicio / Sección» (las migas) de todas las secciones.

**Qué cambió:** se quitó `<nav class="breadcrumbs">` de las 7 secciones que lo tenían: `monetta-collection`, `monetta-collection-list`, `monetta-search`, `monetta-product`, `monetta-page`, `monetta-blog` y `monetta-article`.
- En producto también se quitó su contenedor `.product-breadcrumbs`.
- Las reglas CSS que quedan sin uso viven en hojas generadas (`monetta-pages.css`, paridad de `port-css`) o escritas a mano. No afectan nada y no se tocaron.

**Cómo se subió:** directo al tema publicado `192558366754`, por decisión de la persona, en lugar de pasar por un duplicado.
- Preflight de los 7 archivos: 0 errores.
- Theme Check del tema: 187 errores y 64 avisos, 0 introducidos.
- `shopify theme push --allow-live --only` con esos 7 archivos (28-oct a las 03:22 UTC). El proxy de la persona seguía conectado al tema publicado y también los sincronizó.

**Verificación**
- Con `shopify theme pull --only` (sólo lectura), los 7 archivos del tema publicado son idénticos byte a byte al worktree, y ninguno contiene `class="breadcrumbs"`.
- Responden 200, sin migas, sin «Failed to Upload» y con su `h1`: colección (Bolsas y Coach), producto, búsqueda, Categorías y blog. `/pages/contact` usa la plantilla del owner, sin cambios.
- Capturas a 1440 de Totes y producto (`evidencia/captures/sin-migas/`): no queda hueco.
- `compare-remote.mjs` ya no corre contra este tema, porque se niega con temas publicados (es su resguardo).
- La suite completa no se volvió a correr. Ninguna prueba depende de las migas: sólo `checks.mjs` las exime de la regla de 48 px.

## F9. Buscador predictivo — implementación en borrador; validación de navegador pendiente

**Autorización y destino**
- La persona indicó: «cuando termines, subelo directo a la pagina de staging». Se autorizó preparar el duplicado y desplegarlo en staging después de validar. Esta indicación posterior sustituye la prohibición inicial de publicar, exclusivamente para la entrega en staging.
- Se duplicó `192558366754` sin modificar sus archivos. Nuevo tema: **`192576585762`**, rol **`unpublished`**. Shopify devolvió el nombre truncado «Monetta buscador predictivo borrador sin public...», que se usa literalmente en `THEME.env` para la comprobación de destino.
- `THEME_DIR` apunta a `storefront-theme/` del worktree nuevo `.claude/worktrees/web-buscador-predictivo`; rama local `feat/web-buscador-predictivo`, desde `11ff5db`.
- No se escribió en el tema publicado, en el admin de productos/colecciones/ajustes ni en la app. No hubo push a GitHub ni PR.

**Qué cambió**
- Se conectó `<monetta-predictive-search>` a los formularios existentes del header y de `/search`. Se conservaron los IDs, el GET, `type=product`, `.search-field`, `[data-search-clear]`, `watchSearchClear` y `watchTyping`.
- Con dos caracteres y 200 ms de espera, consulta `query,product,collection`, con límite de seis por recurso, indisponibles al final y `section_id=monetta-predictive-results`.
- La sección devuelve sugerencias con el resaltado de Shopify (`styled_text`), productos con imagen/marca/nombre/precio y precio anterior cuando corresponde (misma selección de variante y formato monetario que las tarjetas), y colecciones. «Ver todos los resultados para «…»» es la última opción seleccionable.
- Estado vacío en español con Bolsas, Carteras, Relojes y Perfumes; los enlaces se resuelven con `monetta-guia-url`.
- Historial único `monetta:recent-searches`, máximo cinco, compartido con la página y sincronizado entre los componentes. Cada reciente se puede quitar; Suprimir también quita la opción reciente seleccionada con las flechas. Los botones están fuera del listbox para evitar controles interactivos anidados en opciones.
- Flechas con `aria-activedescendant`, Enter nativo o activación de la opción, Escape para cerrar y luego borrar, Tab/clic fuera para cerrar; región `aria-live="polite"`.
- Cancelación con `AbortController` y generación de consulta para descartar respuestas antiguas incluso después de cambiar el texto. Caché de hasta 50 respuestas durante la sesión (`sessionStorage`, con respaldo en memoria). Ante error, se cierra el panel y queda disponible el GET normal.
- Panel fijo bajo el campo, vidrio translúcido, Playfair Display, borde de control, filo interior y sombra corta. Ancho de pantalla en teléfono, opciones y botones de 48 px o más; indicador sin desplazamiento del documento y sin animación con movimiento reducido.
- El componente independiente reutiliza el mismo formulario/panel e historial. Sus límites se acotan a seis resultados y cinco recientes.

**Pruebas primero y comprobaciones**

| Comprobación | Antes | Después / estado real |
|---|---|---|
| F9 a 390, 768, 1024 y 1440 | **0/4**: falla en los cuatro tamaños porque el campo existente no está conectado a un componente. Corrida realizada antes de copiar los cambios al tema. | **Pendiente** contra el proxy del duplicado. No se declara aprobada. |
| Preflight Liquid con overlay | — | **10 archivos, 0 errores**; repetido tras ajustar los parámetros y el precio de variante. |
| Theme Check contra línea base | 187 errores y 64 avisos | Primera corrida: 187/66, con dos avisos nuevos por parámetros del snippet. Se corrigieron; segunda: **187/64, 0 hallazgos introducidos**. |
| `node design-system/build.mjs --check` | — | Pasa; 22 pares de contraste. |
| `node tools/style-guideline-theme/port-css.mjs --check` | — | Pasa. |
| `./bin/check_no_secrets.sh` | — | Pasa. |
| `node --check` de los tres JS modificados/nuevos y del arnés F9; `git diff --check` | — | Pasan. |
| Subida protegida al duplicado | — | Dos subidas terminadas con éxito; `theme-push.sh` verificó `unpublished` y el nombre antes de cada una. |
| Comparación remota después de subir | — | **779 archivos de cada lado, 0 diferencias de contenido**; 765 idénticos byte a byte y 14 JSON equivalentes tras el formato de Shopify. |
| Suite completa, axe abierto y revisión de capturas | — | **Pendientes**; no se ejecutaron sobre el cambio. |

**Arnés F9** (`guia-checks.mjs` → `predictive-checks.mjs`): cubre umbral, consulta API, sugerencias/resaltado/productos/colecciones/Ver todos, teclado, navegación por enlace y toque, ARIA, recientes compartidos y eliminación desde ambos lugares, caché entre documentos, respuesta anterior que llega tarde incluso tras el aborto, fallo API con GET funcional, scripts bloqueados, fuentes medidas por CDP y límites del panel entre 320 y 1440. Generará seis capturas de resultados/vacío/recientes a 390 y 1440. `axe.mjs` agrega los tres estados del panel a sus dos tamaños habituales. Estas comprobaciones están escritas, pero su resultado posterior todavía no existe.

**Comandos y evidencia** (todo bajo `guia-1a1/evidencia/`, fuera de git)
- `node guia-checks.mjs --phases=f9 --name=f9-before` con `MONETTA_RUNS_DIR`: exit 1 esperado; `runs/2026-10-28T03-27-02-418Z-f9-before/result.json`, cuatro fallas de conexión. El proxy sirvió el árbol anterior, tema `192558366754`.
- `node .../preflight.mjs --overlay=/private/tmp/monetta-f9-overlay`: exit 0, 10 archivos y 0 errores.
- `node .../theme-check-diff.mjs --out=<ruta absoluta>`: primera salida exit 1 (`validation/f9-local/theme-check`); corregida exit 0 (`validation/f9-local-fixed/theme-check`).
- Build, paridad y secretos: exit 0; salidas en `validation/f9-local-fixed/{build-check,port-parity,secrets}.out`.
- `shopify theme duplicate --store monetta-staging.myshopify.com --theme 192558366754 --name ... --force`: éxito. La primera invocación sin `--force` fue rechazada por la CLI antes de crear el tema; la segunda creó únicamente el duplicado autorizado.
- `shopify theme list --store monetta-staging.myshopify.com --id 192576585762 --json --no-color`: `unpublished`.
- `scripts/theme-push.sh` y, tras ajustes, `scripts/theme-push.sh --only assets/monetta-predictive-search.js --only assets/monetta-predictive-search.css --only snippets/monetta-predictive-search.liquid --only sections/monetta-predictive-results.liquid`: exit 0.
- `node scripts/compare-remote.mjs --out=<ruta absoluta a evidencia/f9/remote-after-upload>`: exit 0; `equivalent: true`, rol `unpublished`, 779 archivos en ambos lados y cero diferencias de contenido. Descarga de sólo lectura, 28-oct 03:40 UTC.
- Sondeo de sólo lectura desde el navegador de la API JSON real: `co` devuelve tres consultas, dos productos y una colección; `bol` seis consultas y seis productos; `guess` seis consultas y seis productos; `zzqx` cero de los tres recursos. Este sondeo comprueba los datos de prueba, **no valida la sección ni el componente nuevo**.

**Pendiente para completar y publicar**
1. La persona debe cerrar el proxy anterior y arrancar `docs/web-redesign/shopify-staging/scripts/start-theme-dev.command` **del worktree nuevo**; la contraseña se escribe sólo en su Terminal, como exige el encargo §4.3. El proxy observado seguía sirviendo `192558366754` y cero componentes predictivos; no se puede usar para aprobar el cambio.
2. Ejecutar F9 sobre el duplicado, investigar y corregir las fallas; revisar sus seis capturas.
3. Ejecutar `GUIA_PHASES=f1,f2,f3,f4,f5,f7,f8,f9 docs/web-redesign/shopify-staging/guia-1a1/scripts/validate.sh f9`, investigar cualquier falla y registrar la evidencia y clasificación. La publicación queda pendiente de esta validación.
4. Comparar el remoto con el worktree final; detener el proxy antes de publicar el duplicado en staging, según la indicación posterior de la persona. Confirmar el rol y la tienda publicados.

**Commits locales hasta aquí:** `5acda91` (pruebas previas), `65b20c1` (implementación y destino protegido).

**Vista previa del duplicado:** <https://monetta-staging.myshopify.com/?preview_theme_id=192576585762>. **Todavía no se publicó.**
