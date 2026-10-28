# Tema web ≈ guía del cliente: plan y prompt de lanzamiento

27 de octubre de 2026. Preparado en la sesión que dejó la app igual a la guía (PR #33).

## 1. Qué se busca

El objetivo es acercar al máximo el borrador del tema de Shopify a la guía del cliente, adaptándolo a web. La guía dibuja una app de teléfono, así que el resultado no será 1:1:

- **Teléfono (≤ 767 px).** La web copia la composición, el orden y los textos de cada lámina.
- **Tablet y escritorio.** Conserva la identidad (fotos, tipografía, colores, textos y componentes) y adapta la composición: navegación visible, rejillas más anchas y hover.
- **Lo que en web no existe o vive fuera del tema** se adapta o se declara fuera de alcance (§5).

La app de PR #33 sirve de intérprete: cuando una lámina sea ambigua, manda lo que hace la app.

## 2. Punto de partida (verificado el 27-oct)

| Pieza | Estado |
|---|---|
| Tema | Borrador sin publicar `192125304866` en `monetta-staging.myshopify.com`. El tema vivo `189719183394` está intacto. |
| Último pase web | 22-oct, alineación con la app de esa fecha. Su registro dice «implementación completa y sincronizada al borrador; validación parcial». Quedaron pendientes `validate.sh`, las capturas «después», el push guardado final y la comparación remota. Una falla de journey a 390 px quedó sin clasificar. |
| Código del tema | `main` tiene el tema hasta el 21-oct (vía #24). El delta del 22-oct existe sólo sin commit en la carpeta principal (rama `feat/client-guide-oct20`): 65 archivos de `storefront-theme/`, `design-system/build.mjs` y los docs. Esa carpeta también tiene cambios de la app (`lib/`, `test/`, `Makefile`, `config/README.md`) que no son de la web. |
| Scripts del tema | `THEME.env` (`THEME_DIR`) y `start-theme-dev.command` apuntan fijo a `/Users/alexis_reyna/MyCode/Monetta/storefront-theme`. |
| App de referencia | PR #33 (`feat/client-guide-borrador-1to1`, `40567de7`), apilado sobre #31. Todavía no está en `main`. |
| Guía | `BORRADOR DE APP.pptx`, 30 láminas. El render y los recortes están en `.claude/worktrees/device-pr31/build/guide-1to1-evidence/`: `pptx-render/borrador.pdf`, `borrador-ref/`, `guide-pages/`, `captures-final/` (app), `owner-assets/` (originales) y `asset-map.txt`. Esa carpeta está ignorada por git y `flutter clean` la borra. |
| Datos de staging | 202 productos. Sólo hay 3 colecciones más `all`. Los filtros son de disponibilidad y precio. Los menús son los de Shopify por defecto, en inglés. |

Diferencias visibles entre las capturas del 22-oct y la guía:

| Pantalla | Web del 22-oct | Guía |
|---|---|---|
| Inicio | Hero partido «Bolsas, carteras y relojes originales» y «Novedades». | Carrusel de foto completa «Compra fácil desde México», Compra por estilo, Tus marcas favoritas, Nueva colección, Precios de mayoreo, servicios y Regístrate. |
| Colección | «Products / 202 piezas», en inglés y sin foto. | Hero con foto por marca o categoría, pastillas, conteo, orden y botón VER PRODUCTO. |
| Tipografía | Playfair Display e Inter. | La app de #33 usa Cormorant Garamond y Mrs Saint Delafield (OFL) en lugar de las fuentes comerciales de la guía. |

## 3. Decisiones antes de lanzar

| # | Decisión | Recomendación |
|---|---|---|
| D1 | Guía de referencia | El BORRADOR de 30 láminas. Sustituye al PDF de 19 páginas y es la que sigue la app. |
| D2 | Rescatar el trabajo del 22-oct | Rama nueva `feat/web-guia-1a1` desde `origin/main`, en el worktree `.claude/worktrees/web-guia-1a1`, con un commit que contenga `storefront-theme/`, `design-system/build.mjs`, los docs de texto (`DESIGN_SPEC.md`, el plan del 22-oct, `HANDOFF.md`, `RUNS.md`, `README.md`) y `shopify-staging/scripts/`. Las carpetas de evidencia pesadas se quedan fuera de git, y los cambios de app de la carpeta principal no se tocan. En el worktree, `THEME_DIR` y `start-theme-dev.command` se apuntan al worktree; la tienda y el ID del tema no cambian. Desde entonces sólo se usan los scripts del worktree. |
| D3 | Colecciones de marca y categoría (13 heroes) | No escribir en el admin. Usar las colecciones automáticas de Shopify (`/collections/vendors?q=Coach`, `/collections/types?q=Totes`) y elegir el hero por nombre. La lista de las 13 colecciones por crear se entrega al owner. La alternativa es autorizar que la sesión las cree en staging. |
| D4 | Fotos | Assets del tema en tres anchos (768, 1280 y 1920 px, WebP), generados con ffmpeg desde los originales del owner. Así no hay que escribir en Shopify Files. |
| D5 | Textos comerciales | Los de la app de #33: mínimo 3 piezas, apartado de mayoreo de $800 por 20 días, envío gratis de mayoreo arriba de $1,999 y envíos garantizados. La guía trae «Regístrate y recibe envío gratis», que la app no muestra; queda fuera salvo que lo apruebes. |
| D6 | Commits | Locales, uno por fase, en la rama del worktree. El push a GitHub, sólo cuando lo pidas. |

Fuera de alcance salvo autorización aparte: el branding del checkout y de las cuentas de cliente (es un ajuste de la tienda), los menús del admin, los productos y los descuentos.

## 4. Reglas de adaptación

Rangos de ancho: teléfono hasta 767 px, tablet de 768 a 1023 y escritorio desde 1024. Desde 320 px no debe haber scroll horizontal.

- **Teléfono:** composición, orden y textos de la lámina. Header con menú, wordmark centrado y buscar. Barra inferior Inicio · Categorías · Carrito · Cuenta.
- **Tablet:** igual que teléfono, con rejillas de 3 columnas y el menú como cajón.
- **Escritorio:**
  - header con navegación visible (Bolsas, Carteras, Relojes, Perfumes, Marcas, Mayoreo), buscar, cuenta y carrito;
  - sin barra inferior;
  - rejillas de 4 columnas, carruseles con flechas y hover;
  - ancho máximo de contenido.
- **Fotos:** las editoriales llevan un recorte intencional (cover); las de producto se ven completas (contain).
- **Accesibilidad:** objetivos táctiles de 48 px, respeto a `prefers-reduced-motion` y foco visible.
- **Lámina contra app:** si difieren, manda la app de #33, salvo un error evidente, que se anota.

## 5. Mapa de láminas

| Lámina | En web | Fidelidad esperada |
|---|---|---|
| 01 Bienvenida | No hay pantalla de bienvenida en web. Su foto y su texto pueden vestir la página de contraseña de staging. | Adaptada |
| 02 Personalización | Shopify no tiene perfil para esto. Opcional: preferencias guardadas en el navegador que ordenen los rieles del inicio. | Fuera (opcional) |
| 03 Inicio | Carrusel de 3 fotos, Compra por estilo con los iconos de la guía, Tus marcas favoritas, Nueva colección (un riel de productos en lugar del video), Precios de mayoreo, servicios y pie. | Alta |
| 04 Inicio (seguimiento) | Bloque «Rastrea tu pedido» que lleva a los pedidos de Shopify. Sin seguimiento en vivo. | Adaptada |
| 05 Búsqueda | Búsqueda predictiva y página de resultados: búsquedas recientes (guardadas en el navegador), sugerencias por categoría y productos. | Alta |
| 06–11 Colecciones de marca | Hero con foto y nombre de la marca, pastillas, conteo, orden y tarjetas con VER PRODUCTO. | Alta (depende de D3) |
| 12 Preview | Vista rápida: modal en escritorio, hoja inferior en teléfono. | Alta |
| 13 Producto | Galería con miniaturas, colores, precio y descuento, AGREGAR A LA BOLSA, fila de confianza, acordeones y relacionados. Sin reseñas, puntos ni stock real, igual que la app. | Alta |
| 14–20 Colecciones de categoría | Igual que las de marca. | Alta (depende de D3) |
| 21–22 Mayoreo | `page.mayoreo`: hero, ¿Cómo comprar? en 3 pasos, banners de Bolsos y carteras y de Perfumes, WhatsApp y productos. | Alta |
| 23 Mis pedidos, 24 Mi cuenta | Viven en las cuentas de cliente de Shopify, fuera del tema. El tema sólo controla el acceso «Cuenta». | Fuera del tema |
| 25–26 Rewards | Página informativa «Monetta Rewards» y «Comparte y gana» con copiar el enlace del catálogo. Sin puntos, porque no hay backend. | Parcial |
| 27 Contacto | `page.contact`: hero, WhatsApp, grupos, redes y el formulario de Shopify. | Alta |
| 28 Compra | El checkout y la página de gracias son de Shopify. El carrito sí sigue la guía. | Fuera del tema (carrito: alta) |
| 29 Categorías | Página de categorías con iconos y marcas (`list-collections`). | Alta |
| 30 Menú | Cajón con la estructura de la guía en teléfono y tablet. En escritorio, la navegación más el mismo cajón. | Alta |

## 6. Fases

**P. Preparación.** La hace la sesión nueva, después de que la persona confirme D1–D6:

1. Crear el worktree: `git worktree add --no-track -b feat/web-guia-1a1 .claude/worktrees/web-guia-1a1 origin/main`.
2. Traer el delta del 22-oct **como parche**, no copiando carpetas enteras. `main` movió `port-css.mjs` a `tools/style-guideline-theme/`, y una copia de carpetas revertiría ese cambio.
   - Los cambios rastreados salen de `git diff HEAD -- storefront-theme design-system/build.mjs` en la carpeta principal y se aplican con `git apply --3way`.
   - El cambio de `docs/web-redesign/shopify-staging/scripts/port-css.mjs` (añade `--check`) se aplica a `tools/style-guideline-theme/port-css.mjs`.
   - Los archivos nuevos del tema salen de `git ls-files --others --exclude-standard -- storefront-theme`.
   - Docs de texto: `docs/web-redesign/DESIGN_SPEC.md`, el plan del 22-oct, `shopify-staging/{README.md,ENTREGA.md,RUNS.md,THEME.env}`, `design-language-2026-10-22/HANDOFF.md` y este plan.
   - Arneses: `shopify-staging/scripts/` (sin `port-css.mjs`) y `design-language-2026-10-22/scripts/`.
   - Las carpetas pesadas (`runs/` con 60 MB, capturas, baselines) se quedan en la carpeta principal y se leen por ruta absoluta.
3. En el worktree, apuntar `THEME_DIR` y `start-theme-dev.command` al `storefront-theme/` del worktree. La tienda y el ID del tema no cambian.
4. Comprobar:
   - el tema del worktree es igual al de la carpeta principal, salvo las rutas de `port-css`;
   - pasan `node design-system/build.mjs --check`, el `--check` de `port-css` y `./bin/check_no_secrets.sh`;
   - `THEME.env` sólo entra en el commit si no tiene secretos.
5. Hacer el commit local.
6. Copiar las referencias de `.claude/worktrees/device-pr31/build/guide-1to1-evidence/` a `docs/web-redesign/shopify-staging/guia-1a1/refs/`:
   - `slides/` ← `borrador-ref/` y `pptx-render/borrador.pdf`;
   - `app/` ← `captures-final/`;
   - `owner/` ← `owner-assets/`.

   `refs/` va en `.git/info/exclude`, porque el repo es público.

**F0–F6.** Las hace la misma sesión. Cada fase cierra con una hoja comparativa (lámina | web a 390×844 | web a 1440×900 | app), sus comprobaciones y un commit local.

- **F0. Línea base, sin tocar el tema:**
  - confirmar el rol `unpublished`;
  - respaldar el remoto con SHA-256;
  - cerrar los pendientes del 22-oct y clasificar la falla de journey;
  - tomar las capturas «antes».
- **F1. Base visual:**
  - fuentes: Cormorant Garamond (300, 400 y 500, con itálicas) y Mrs Saint Delafield, en woff2 si hay herramienta y, si no, en TTF;
  - tokens del lado de Shopify;
  - los 21 iconos y las fotos en tres anchos;
  - componentes base: pastilla dorada, hero con texto, tarjeta con VER PRODUCTO y títulos de sección.
- **F2.** Inicio, header, menú y barra inferior.
- **F3.** Colecciones de marca y categoría, Categorías y Búsqueda.
- **F4.** Vista rápida, Producto y Carrito.
- **F5.** Mayoreo, Contacto, Rewards / Comparte y gana y el acceso a Cuenta.
- **F6.** Verificación completa, push guardado al borrador, comparación remota y entrega.

Criterios de aceptación por pantalla:

- Textos idénticos a los de la app de #33, o a los de la guía donde la app no tenga la pantalla.
- Fuentes medidas en el navegador con CDP `getPlatformFontsForNode`, no supuestas.
- Sin desbordes de 320 a 1440 px y con objetivos de 48 px.
- `scripts/checks.mjs`, journeys, axe, teclado y movimiento sin regresiones.
- Theme Check sin errores nuevos (línea base: 187 errores y 64 avisos).
- Cada comprobación nueva demuestra que falla en el árbol anterior.

## 7. Límites

- **Publicación:** nunca publicar. Sólo se toca el tema `192125304866`, y su rol se verifica antes y después de cada push. El tema vivo y producción no se tocan.
- **Admin de Shopify:** no se escriben productos, colecciones, menús, descuentos, ajustes ni checkout sin la decisión correspondiente.
- **App:** no se tocan `lib/`, `test/` ni el manifiesto de tokens compartido. Si hace falta un token nuevo, se agrega del lado de Shopify y se anota.
- **Fuentes de la guía:** nunca se extraen del PPTX las comerciales (Reglarik y Above the Beyond Script).
- **Repositorio:** las láminas del owner no van a git, porque el repo es público. No hay push a GitHub hasta que la persona lo pida.
- **Navegador:** no se usa Chrome; se usa Brave headless con `playwright-core`.
- **Contraseña:** la de la tienda la escribe la persona en su Terminal, nunca en el chat.
- **Scripts:** sólo se usan los del worktree; los de la carpeta principal sincronizarían otra copia del tema al borrador.

## 8. Riesgos

- La sesión de `shopify theme dev` caduca a las 2 horas aproximadamente (401 `{"error":"unauthorized"}`). Hay que reiniciarla, y nunca correr dos a la vez.
- Las colecciones y los menús de staging no reflejan la guía (ver D3).
- Cuentas, pedidos y checkout no se pueden tematizar: van a quedar distintos de la guía.
- #33 todavía no está en `main`; si cambia, la web puede desfasarse.
- Los bots de #31 siguen activos.
- El alcance es grande (20 pantallas distintas). Si la sesión no termina, la siguiente continúa desde la última fase cerrada.

## 9. Cómo lanzar

1. En tu Terminal: `cd /Users/alexis_reyna/MyCode/Monetta && claude` (Opus 5.5).
2. Pega el prompt de abajo. Lo primero que hará la sesión es mostrarte D1–D6 para que las confirmes.
3. Cuando termine la preparación, te pedirá correr en otra ventana `start-theme-dev.command` **del worktree** y escribir ahí la contraseña de la tienda.

```text
Eres la sesión de diseño e implementación del tema web de Monetta en Shopify. Arrancas en la
carpeta principal /Users/alexis_reyna/MyCode/Monetta, pero ahí sólo lees: todo lo que escribas va
en el worktree que crearás en el paso P.

Objetivo: llevar el tema borrador 192125304866 de monetta-staging.myshopify.com lo más cerca
posible de la guía del cliente «BORRADOR DE APP» (30 láminas), adaptado a web. No es un 1:1:
en teléfono copias la composición de cada lámina; en tablet y escritorio conservas la identidad
(fotos, fuentes, colores, textos y componentes) y adaptas la composición. La app de PR #33
interpreta la guía: si una lámina es ambigua, manda lo que hace la app.

Lee primero:
1. docs/prompts/MONETTA_WEB_GUIA_1A1_PLAN_2026-10-27.md. Es tu contrato: punto de partida,
   decisiones D1–D6, mapa de láminas, fases P y F0–F6, criterios de aceptación y límites.
2. .claude/CLAUDE.md: reglas del repo, sandbox y estilo. Su programa de refactor no aplica: esto
   no es un WP y no usa los subagentes del refactor.
3. docs/web-redesign/shopify-staging/design-language-2026-10-22/HANDOFF.md,
   docs/web-redesign/DESIGN_SPEC.md y docs/web-redesign/shopify-staging/README.md: estado del
   tema, scripts y arnés de pruebas.

Paso 0, antes de escribir nada: muéstrame D1–D6 del plan con su recomendación, en una sola
pregunta, y espera mi respuesta. Lo que yo decida manda sobre el plan.

Paso P: haz la preparación exactamente como la describe el §6 del plan.
- Trae el trabajo del 22-oct como parche, no copiando carpetas enteras: main movió port-css.mjs a
  tools/style-guideline-theme/.
- No toques los cambios de app de la carpeta principal (lib/, test/, Makefile, config/README.md).
- Apunta THEME.env y start-theme-dev.command al worktree. Desde entonces usa sólo los scripts del
  worktree: los de la carpeta principal subirían otra copia del tema al borrador.
- Comprueba y haz el commit local en feat/web-guia-1a1.
- Copia las referencias a guia-1a1/refs/, excluidas de git.
- Al terminar, pídeme abrir el proxy.

Después, las fases F0–F6 del plan, en orden. Al cerrar cada fase: hoja comparativa (lámina | web
390×844 | web 1440×900 | app), las comprobaciones del plan, una entrada en
docs/web-redesign/shopify-staging/guia-1a1/RESULTADO.md y un commit local. Sin push.

Referencias:
- Láminas en guia-1a1/refs/slides/ y capturas de la app en refs/app/. Abre las imágenes; no te
  quedes con los nombres.
- El código de #33 se lee con git show feat/client-guide-borrador-1to1:<ruta>, sin checkout.
  Empieza por lib/features/boutique/ (guide_art.dart, client_guide_components.dart y
  client_guide_sections.dart); sigue con home, catalog, product, wholesale, contact y navigation,
  y con pubspec.yaml para las fuentes.
- Las fotos, los iconos y las fuentes OFL salen de esa misma rama. Los originales en alta
  resolución están en refs/owner/.

Herramientas:
- Brave headless con playwright-core (design-prototype/node_modules). Nunca instales Chrome.
- La vista previa autenticada es http://127.0.0.1:9292. Si responde 401 {"error":"unauthorized"},
  pídeme reiniciar el proxy. Nunca pidas la contraseña en el chat.
- Sube al borrador sólo con scripts/theme-push.sh del worktree, después de verificar que el tema
  sigue unpublished. Antes del primer push, respalda el remoto con SHA-256.

Lo reversible lo decides tú y lo anotas. Pregunta sólo ante una decisión que el plan no resuelva y
que bloquee el avance, o antes de cualquier escritura fuera del tema 192125304866.

Lo crítico, otra vez:
- Nunca publiques ni toques otro tema o producción.
- No escribas en el admin de Shopify.
- No toques lib/ ni test/ de la app.
- Nunca extraigas del PPTX las fuentes comerciales (Reglarik y Above the Beyond Script).
- Los textos comerciales son los de la app de #33.
- Las láminas y las fotos originales del owner no van a git.
- Ninguna comprobación cuenta si no demostraste que falla en el árbol anterior.

Termina con:
- el borrador actualizado y su liga de vista previa
  (https://monetta-staging.myshopify.com/?preview_theme_id=192125304866);
- RESULTADO.md con la tabla lámina por lámina: la fidelidad lograda y, donde no sea mayor, por qué;
- la lista de lo que depende del owner: colecciones, menús y branding del checkout.
```
