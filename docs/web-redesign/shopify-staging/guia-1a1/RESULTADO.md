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
