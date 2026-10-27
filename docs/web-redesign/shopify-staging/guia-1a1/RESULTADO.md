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
