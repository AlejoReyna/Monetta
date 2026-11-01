# Encargo para Codex: buscador predictivo «tipo Google» en el tema Shopify de Monetta

## 1. Objetivo

Que el buscador de la tienda funcione como el de Google: mientras la persona escribe, aparece debajo del campo una lista de resultados. Al elegir uno, va directo a ese producto o a esa búsqueda.

Hoy no pasa nada al escribir. El campo sólo envía el formulario a `/search` cuando se pulsa Enter.

Aplica a dos campos:
- el buscador del header (tablet y escritorio, desde 768 px);
- el campo de la página de búsqueda `/search`, que es el que se usa en teléfono: ahí el header sólo muestra una lupa que lleva a `/search`.

## 2. Contexto

- **Repositorio:** `/Users/alexis_reyna/MyCode/Monetta`. Es público: nada de secretos, contraseñas ni fotos o láminas del owner en git.
- **Tema:** `storefront-theme/`, basado en Atelier 3.5.0, con layout propio `layout/monetta.liquid`.
- **Tienda:** `monetta-staging.myshopify.com`.
- **Rama base:** `feat/web-guia-1a1`, sólo local; no existe en GitHub. Está en el worktree `/Users/alexis_reyna/MyCode/Monetta/.claude/worktrees/web-guia-1a1`. Commit de referencia: `11ff5db` o posterior.
- **Registro de la pasada anterior:** `docs/web-redesign/shopify-staging/guia-1a1/RESULTADO.md` (fases F0–F8). Léelo antes de empezar.

**Importante:** el tema **192558366754** ya está **PUBLICADO** en staging desde el 28-oct; es lo que ve el owner. Nunca escribas en él. Ver §6.

**Piezas que ya existen:**

| Pieza | Archivo | Estado |
|---|---|---|
| Buscador del header | `sections/monetta-header.liquid` | `form.header-search` > `.search-field` > `input#header-search-input`, más el botón `[data-search-clear]` y un `input[name=type][value=product]` oculto |
| Estilo del buscador del header | `assets/monetta-guia.css`, bloque final «Header: liquid-glass search» | F8: vidrio translúcido; Playfair Display 500 para el texto. Base en `assets/monetta-components.css` (`.search-field`) |
| Campo de la página de búsqueda | `sections/monetta-search.liquid` | `input#page-search-input` |
| Comportamiento existente | `assets/monetta-core.js` (`watchTyping`, `watchSearchClear`) y `assets/monetta-guia.js` | «Búsquedas recientes» de la página `/search`: clave `localStorage` `monetta:recent-searches`, máximo 5, cada una con botón para quitarla |
| Componente predictivo, **existe pero NO está conectado** a ningún campo ni plantilla | `assets/monetta-predictive-search.js` (custom element `<monetta-predictive-search>`), `snippets/monetta-predictive-search.liquid`, `sections/monetta-predictive-search.liquid`, `sections/monetta-predictive-results.liquid`, `assets/monetta-predictive-search.css`, `snippets/monetta-predictive-copy.liquid` | `monetta-predictive-results` es la sección «sólo API» que responde a `/search/suggest?...&section_id=monetta-predictive-results`. Hoy sólo pide `resources[type]=product`. Usa su propia clave de historial (`monetta:predictive:recent:v1:…`). |

Decide si reutilizas ese componente o lo adaptas. Hay dos condiciones:
- el historial debe ser **uno solo**, el de `monetta:recent-searches`, compartido con la página de búsqueda;
- no se puede romper el botón de borrar ni el envío normal del formulario.

**Datos de staging que importan:**
- 202 productos.
- Marcas con productos: Coach, Guess, Michael Kors y Steve Madden.
- Etiquetas limpias: Tote, Shoulder, Crossbody, Satchel, Carteras y Reloj. Los tipos de producto están desordenados.
- Sólo hay 3 colecciones más `all`.
- El idioma de la tienda es inglés, pero toda la UI va en español escrito en la plantilla.

## 3. Qué debe hacer (requisitos)

**Al escribir** (2 o más caracteres, con 150–250 ms de espera tras la última tecla), se abre un panel bajo el campo con:
1. **Sugerencias de búsqueda:** el recurso `query` de la Predictive Search API, con la parte escrita resaltada. Al elegir una, va a `/search?q=<sugerencia>&type=product`.
2. **Productos:** hasta 6, cada uno con foto, marca, nombre y precio (con el precio tachado si hay descuento, como en las tarjetas del tema). Al elegir uno, va al producto.
3. **Colecciones o categorías** que coincidan, si las hay.
4. Una última opción: **«Ver todos los resultados para «…»»**, que lleva a `/search?q=…&type=product`.

**Otros estados del panel:**
- **Sin resultados:** «No encontramos resultados para «…»». Debajo, las sugerencias Bolsas, Carteras, Relojes y Perfumes, con los destinos de `snippets/monetta-guia-url.liquid`.
- **Campo vacío y enfocado:** «Búsquedas recientes» (la misma lista de la página `/search`), cada una con su botón para quitarla. Si no hay recientes, no se abre nada.
- **Mientras carga:** un indicador discreto que no mueva el layout. Además:
  - cancela la petición anterior con `AbortController`;
  - ignora respuestas que lleguen fuera de orden;
  - guarda en caché las respuestas de cada consulta durante la sesión.
- **Si la API falla:** el panel se cierra en silencio y Enter sigue buscando normal.

**Teclado** (patrón ARIA *combobox* con *listbox*, como Google):
- ↓/↑ recorren las opciones con `aria-activedescendant`, sin mover el foco del input;
- Enter abre la opción activa o, si no hay ninguna, envía la búsqueda;
- Esc cierra el panel; un segundo Esc borra el texto;
- Tab sale del campo y cierra el panel.

**Mouse y pantalla táctil:** clic o toque en una opción la abre; un clic fuera cierra el panel.

**Accesibilidad:**
- En el input: `role="combobox"`, `aria-expanded`, `aria-controls` y `aria-autocomplete="list"`.
- Una región `aria-live="polite"` anuncia «N resultados» o «Sin resultados».
- Objetivos táctiles de 48 px; foco visible.
- Sin hallazgos serios ni críticos de axe con el panel abierto.

**Diseño:**
- El panel sigue el vidrio del buscador de F8: fondo blanco translúcido con `backdrop-filter`, borde `--color-border-control`, filo claro interior y sombra corta.
- Textos en Playfair Display, como el header.
- Sin desbordes de 320 a 1440 px.
- En teléfono, el panel ocupa el ancho de la pantalla bajo el campo de `/search`.
- Respeta `prefers-reduced-motion`.

**Sin cambios:**
- el envío normal del formulario (sin JavaScript también funciona);
- el botón de borrar;
- la página `/search` y sus filtros;
- `watchTyping`.

**Rendimiento:** la API se llama sólo desde el navegador, con
`GET {{ routes.predictive_search_url }}?q=…&resources[type]=query,product,collection&resources[limit]=6&resources[limit_scope]=each&resources[options][unavailable_products]=last&section_id=monetta-predictive-results`.
Amplía la sección para que pinte también `queries` y `collections`.

## 4. Cómo trabajar

1. **Worktree nuevo** desde la rama local, y el enlace de `node_modules` que usa el arnés:
   ```
   git worktree add -b feat/web-buscador-predictivo /Users/alexis_reyna/MyCode/Monetta/.claude/worktrees/web-buscador-predictivo feat/web-guia-1a1
   ln -s /Users/alexis_reyna/MyCode/Monetta/design-prototype/node_modules /Users/alexis_reyna/MyCode/Monetta/.claude/worktrees/web-buscador-predictivo/design-prototype/node_modules
   ```
   No trabajes en la carpeta principal: otra sesión la usa y se detiene si encuentra archivos que no escribió. Nunca uses `git stash` sin etiqueta.
2. **Tema de trabajo.** Antes de escribir en la tienda, **pide autorización a la persona** para crear un duplicado sin publicar:
   ```
   shopify theme duplicate --store monetta-staging.myshopify.com --theme 192558366754 --name "Monetta buscador predictivo borrador sin publicar <fecha>"
   ```
   - Confirma con `shopify theme list` que el duplicado quedó `unpublished`.
   - En el `THEME.env` del worktree nuevo (`docs/web-redesign/shopify-staging/THEME.env`), pon `THEME_ID` y `THEME_NAME` del duplicado, y `THEME_DIR` con la ruta absoluta al `storefront-theme/` del **worktree nuevo**. Hoy apunta al de `web-guia-1a1`; si no lo cambias, el proxy sincronizaría la carpeta equivocada.
3. **Proxy.** Pide a la persona que corra en su Terminal `docs/web-redesign/shopify-staging/scripts/start-theme-dev.command` **del worktree nuevo**. Ella escribe ahí la contraseña de la tienda; nunca se la pidas por chat.
   - El script se niega a arrancar si el tema no está sin publicar.
   - El proxy queda en `http://127.0.0.1:9292` y sincroniza cada archivo guardado al duplicado.
   - Su sesión dura unas 2 horas; si responde 401, pide que lo reinicie. Nunca corras dos a la vez.
4. **Trampas conocidas:**
   - Un solo error de sintaxis Liquid, en cualquier archivo y aunque no se use, hace que el proxy sirva «Failed to Upload Theme Files» en todas las rutas. Antes de guardar Liquid en `storefront-theme/`, prepara el archivo en una carpeta aparte y corre `node docs/web-redesign/shopify-staging/guia-1a1/scripts/preflight.mjs --overlay=<carpeta absoluta con la misma estructura del tema>`.
   - Liquid no acepta filtros dentro de `for`: asigna primero.
   - Una plantilla JSON nueva que usa una sección nueva puede subirse antes que la sección y romper todo. Sube la sección, espera y luego haz `touch` a la plantilla.
   - El navegador de pruebas es Brave sin interfaz con `playwright-core` (`scripts/e2e/lib.mjs`). No instales Chrome.
   - El texto escrito en un `<input>` se mide con CDP dentro de su shadow DOM: copia `inputPlatformFonts` de `guia-1a1/scripts/guia-checks.mjs`.
5. **Estilo:**
   - código, comentarios y nombres en inglés, como el código vecino;
   - textos de la UI en español;
   - el registro en `RESULTADO.md`, en español;
   - nada de `// ignore`, nada de pruebas con `skip` y no debilites pruebas existentes.

## 5. Validación (obligatoria; el reporte no cuenta como evidencia)

1. **Pruebas primero.** Agrega una fase `f9` a `docs/web-redesign/shopify-staging/guia-1a1/scripts/guia-checks.mjs`, a 390 (campo de `/search`), 768, 1024 y 1440 (header). Debe cubrir:
   - abre con 2 caracteres;
   - muestra sugerencias, productos y «Ver todos»;
   - el resaltado;
   - ↓/↑, Enter y Esc;
   - el clic en un producto llega a su URL;
   - el estado sin resultados (por ejemplo, «zzqx»);
   - recientes con el campo vacío, que se pueden quitar y comparten la clave `monetta:recent-searches`;
   - los atributos ARIA y la región `aria-live`;
   - una respuesta lenta: la anterior, cancelada o descartada, no reemplaza a la nueva;
   - sin desbordes;
   - fuentes medidas en Playfair;
   - con JavaScript apagado (`page.route` que aborte el script), Enter sigue llevando a `/search`.

   Córrelas en el árbol **antes** del cambio y comprueba que fallan por la razón correcta.
2. Implementa y vuelve a correrlas hasta que todas pasen.
3. **Suite completa**, con el proxy activo:
   ```
   GUIA_PHASES=f1,f2,f3,f4,f5,f7,f8,f9 docs/web-redesign/shopify-staging/guia-1a1/scripts/validate.sh f9
   ```
   Tarda unos 30 minutos. Debe quedar sin fallas:
   - Theme Check sin hallazgos nuevos (línea base: 187 errores y 64 avisos);
   - `checks.mjs` 315/315;
   - journeys a 390, 768, 1024 y 1440;
   - axe (agrega el panel abierto a `scripts/e2e/axe.mjs`);
   - teclado, navegación, layout, regresiones y movimiento;
   - `node design-system/build.mjs --check`, `node tools/style-guideline-theme/port-css.mjs --check` y `./bin/check_no_secrets.sh`.

   Toda falla se investiga y se clasifica (defecto nuevo, defecto anterior o inestabilidad del entorno), con evidencia. Nunca declares aprobada una prueba que no corriste.
4. **Revisión visual:** capturas del panel abierto (con resultados, sin resultados y recientes) a 390 y 1440, en `guia-1a1/evidencia/` (fuera de git), y revísalas.

## 6. Límites (no negociables)

- **Nunca** publiques un tema. **Nunca** escribas en `192558366754`, que está publicado, ni en otro tema que no sea el duplicado autorizado. Antes de cada subida, verifica que el rol del tema sea `unpublished` (`scripts/theme-push.sh` ya lo hace).
- No escribas en el admin de Shopify: productos, colecciones, menús, páginas, ajustes ni Search & Discovery. Si hace falta un ajuste del admin para afinar la búsqueda (por ejemplo, sinónimos), anótalo para el owner.
- No toques `lib/`, `test/` ni la app Flutter, ni el manifiesto de tokens compartido.
- **Commits locales** en `feat/web-buscador-predictivo`, uno por paso lógico, con mensaje en inglés. **Sin push** a GitHub y sin PR hasta que la persona lo pida.

## 7. Entregables

1. Commits locales en `feat/web-buscador-predictivo`.
2. Una entrada «F9. Buscador predictivo» en `docs/web-redesign/shopify-staging/guia-1a1/RESULTADO.md`, con el formato de las fases anteriores:
   - qué cambió;
   - la tabla antes/después de cada comprobación;
   - cada comando con su resultado;
   - lo que quedó pendiente;
   - lo que le toca al owner.
3. Un resumen corto para la persona con el link de vista previa del duplicado: `https://monetta-staging.myshopify.com/?preview_theme_id=<ID del duplicado>`. Con eso decide si se publica.
