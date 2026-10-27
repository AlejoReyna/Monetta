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
