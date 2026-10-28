# Continuación: tema web de Monetta (staging) después de la pasada «guía 1:1»

Pega esto al iniciar una sesión nueva de Claude Code en `/Users/alexis_reyna/MyCode/Monetta`.

---

Continúa el trabajo del tema Shopify de Monetta en staging. La sesión anterior (27–28 de octubre de 2026) terminó la pasada «tema web ≈ guía del cliente» y publicó el tema. Antes de hacer nada, lee:

1. La memoria del proyecto `shopify-staging-theme-f1-status.md` (en `~/.claude/projects/-Users-alexis-reyna-MyCode-Monetta/memory/`). Tiene el historial, las trampas y los datos de staging.
2. `docs/web-redesign/shopify-staging/guia-1a1/RESULTADO.md`, en el worktree de abajo. Registra las fases F0–F8, la publicación y el retiro de las migas, con cada comprobación y su resultado.

## Dónde está todo

- **Worktree:** `/Users/alexis_reyna/MyCode/Monetta/.claude/worktrees/web-guia-1a1`.
  - Rama `feat/web-guia-1a1`, **sólo local**: nunca se subió a GitHub. Último commit: el que guarda este archivo (base `1f1e212`).
  - Trabaja ahí o en otro worktree. **Nunca** en la carpeta principal: la usa el bucle `/refactor` y se detiene si encuentra archivos que no escribió. Su `THEME.env` y sus scripts apuntan al tema viejo; no los corras.
- **Tema:** `storefront-theme/`, sobre Atelier 3.5.0, con layout propio `layout/monetta.liquid` y hojas `assets/monetta-*.css`. Lo de la guía está sobre todo en `assets/monetta-guia.css`, `assets/monetta-guia.js` y `sections/monetta-guia-*.liquid`.
- **Tienda:** `monetta-staging.myshopify.com`, tienda de desarrollo con contraseña. La puerta de contraseña es la genérica de Shopify, no la del tema.
- **Temas:**

  | ID | Rol | Nombre | Nota |
  |---|---|---|---|
  | **192558366754** | **PUBLICADO** desde el 28-oct a las 03:05 UTC | «Monetta guía 1a1 borrador sin publicar 2026-10-27» | Es el que ve el owner. El nombre está desactualizado; renombrarlo es otra escritura en la tienda y la persona no la ha pedido. |
  | 192125304866 | Sin publicar | Tema F1 anterior | Se puede volver a publicar para revertir. |

- **Link para el owner:** <https://monetta-staging.myshopify.com>. Si el navegador muestra la barra «Draft» de un tema viejo, hay que dar clic en «Exit preview»: es una cookie de vista previa.

## Qué se hizo (resumen)

- **F1–F7:** base visual de la guía; Inicio; header, cajón y barra inferior; colecciones con foto, pastillas y VER PRODUCTO; Categorías; Búsqueda con recientes; vista rápida; producto; Mayoreo; Contacto con formulario; Monetta Rewards y Comparte y gana; bienvenida en la plantilla de contraseña. Esta última no se ve en la tienda de desarrollo.
- **Corregido de paso:** un defecto real de la flecha de regreso. Con red lenta, su respaldo de 500 ms borraba el historial hacia adelante.
- **F8:** buscador del header tipo *liquid glass*; Cuenta, Carrito y el texto del buscador en Playfair Display, como la fila de categorías.
- **Después de publicar:** se quitaron las migas «Inicio / Sección» de todas las secciones, con push directo al tema publicado porque así lo eligió la persona.
- **Validación final:** toda la suite en verde. Única excepción: la repetición de teclado tras el último ajuste de sombra se cortó al publicar (89 pasaron, 1 falla conocida de entorno a 375 px).

## Encargado aparte a Codex

El buscador predictivo «tipo Google», con resultados mientras se escribe. El prompt está en `docs/prompts/MONETTA_WEB_BUSCADOR_PREDICTIVO_CODEX_2026-10-28.md`. Codex trabaja en su propio worktree (`feat/web-buscador-predictivo`) y en un duplicado sin publicar. No toques esos archivos sin coordinarlo con la persona.

## Pendientes (pregúntale a la persona cuál sigue)

**Del tema** (los puede hacer Claude):
- Personalización (lámina 02, opcional).
- Página de búsqueda en teléfono: resultados en 3 columnas y el header de la lámina.
- Buscador *glass* también en `/search` y en la 404.
- Ícono de carrito en el paso 2 de Mayoreo.
- Renombrar el tema publicado.
- Terminar la prueba de teclado.
- Subir la rama a GitHub y abrir el PR, sólo si la persona lo pide.

**Del owner** (admin de Shopify):
- crear las páginas Mayoreo y Rewards y asignar las plantillas `guia-mayoreo`, `guia-rewards` y `guia-contacto` (mientras tanto se usa `?view=`);
- crear las 13 colecciones de marca y categoría;
- activar filtros en Search & Discovery;
- subir productos de Tory Burch, Kate Spade y Marc Jacobs;
- traducir los menús del admin.

**Fuera del tema:** checkout, página de gracias, cuentas de cliente, backend de puntos de Rewards, cotización de mayoreo, y que la app y la web compartan tienda.

## Reglas para cambiar el tema

1. **El tema publicado no se toca sin que la persona lo elija explícitamente en ese momento.** Para cambios que necesitan prueba en navegador, el camino seguro es:
   - duplicar el tema publicado (`shopify theme duplicate`, con permiso);
   - apuntar el `THEME.env` del worktree al duplicado: `THEME_ID`, `THEME_NAME` y `THEME_DIR`;
   - probar ahí y publicar el duplicado sólo si la persona lo pide.

   `scripts/theme-push.sh`, `start-theme-dev.command` y `compare-remote.mjs` se niegan a trabajar con un tema publicado.
2. **El proxy** es `docs/web-redesign/shopify-staging/scripts/start-theme-dev.command` del worktree. Lo corre la persona en su Terminal y ahí escribe la contraseña; nunca se la pidas por chat. Sincroniza cada archivo guardado al tema de `THEME.env`, dura unas 2 horas y nunca deben correr dos a la vez. **Verifica que la persona haya cerrado el proxy anterior**: quedó conectado al tema publicado.
3. **Antes de guardar Liquid** en `storefront-theme/`, prepara el archivo en una carpeta aparte y corre:
   ```
   node docs/web-redesign/shopify-staging/guia-1a1/scripts/preflight.mjs --overlay=<carpeta absoluta>
   ```
   Un solo error de Liquid rompe todas las páginas del proxy. Liquid no acepta filtros dentro de `for`. Si una plantilla JSON nueva usa una sección nueva, sube la sección primero y luego haz `touch` a la plantilla.
4. **Validación:**
   ```
   GUIA_PHASES=f1,f2,f3,f4,f5,f7,f8 docs/web-redesign/shopify-staging/guia-1a1/scripts/validate.sh <etiqueta>
   ```
   Tarda unos 30 minutos y debe correr con el proxy activo. Las pruebas nuevas van en `guia-1a1/scripts/guia-checks.mjs` como fase nueva, y deben fallar en el árbol anterior antes de implementar. Theme Check no debe introducir hallazgos (línea base: 187 errores y 64 avisos). El navegador es Brave sin interfaz con `playwright-core`; no instales Chrome. Cada falla se clasifica con evidencia; nunca declares aprobada una prueba que no corriste.
5. **Estilo:** código y comentarios en inglés, como el vecino; textos de UI en español; registro en `RESULTADO.md`, en español. Evidencia pesada, fotos y láminas del owner van en `guia-1a1/evidencia/` y `refs/`, fuera de git, porque el repo es público.
6. **Commits:** locales en la rama del worktree, con la línea `Co-Authored-By` que indique el sistema. Sin push ni PR hasta que la persona lo pida.
7. **Seguridad:** sin secretos en archivos; no escribas en el admin de Shopify (productos, colecciones, menús, páginas, ajustes) sin una decisión de la persona; no toques `lib/`, `test/` ni la app Flutter.

## Primer paso

1. Corre `git -C /Users/alexis_reyna/MyCode/Monetta/.claude/worktrees/web-guia-1a1 log --oneline -5` y `shopify theme list --store monetta-staging.myshopify.com` para confirmar el estado de arriba.
2. Pregunta a la persona si cerró el proxy.
3. Pregúntale qué pendiente sigue.
