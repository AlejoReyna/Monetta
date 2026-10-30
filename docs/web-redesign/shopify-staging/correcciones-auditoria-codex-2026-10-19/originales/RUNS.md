# Índice de ejecuciones

Generado por `scripts/runs-index.mjs` a partir de `runs/*/result*.json`. Cada fila identifica tienda, tema, estado del código (SHA-256 del árbol de `storefront-theme/`), comando y hora. `complete-*` = ejecución completa; `partial` = subconjunto de tamaños o páginas, nunca presentado como resultado completo.

| Hora (UTC) | Ejecución | Estado | Checks | Tienda · tema | Árbol del tema (SHA-256) | Comando |
|---|---|---|---|---|---|---|
| 2026-10-19T10:09:05Z | [journey-375x812](runs/2026-10-19T10-09-05-342Z-journey-375x812/result.json) | complete-pass | 55/55 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=375 --h=812` |
| 2026-10-19T10:09:41Z | [journey-440x956](runs/2026-10-19T10-09-41-366Z-journey-440x956/result.json) | complete-pass | 55/55 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=440 --h=956` |
| 2026-10-19T10:10:16Z | [journey-768x1024](runs/2026-10-19T10-10-16-537Z-journey-768x1024/result.json) | complete-pass | 52/52 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=768 --h=1024` |
| 2026-10-19T10:10:42Z | [journey-1024x768](runs/2026-10-19T10-10-42-390Z-journey-1024x768/result.json) | complete-pass | 52/52 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=1024 --h=768` |
| 2026-10-19T10:11:07Z | [journey-1440x900](runs/2026-10-19T10-11-07-400Z-journey-1440x900/result.json) | complete-pass | 51/51 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=1440 --h=900` |
| 2026-10-19T10:42:15Z | [journey-812x375](runs/2026-10-19T10-42-15-755Z-journey-812x375/result.json) | complete-with-failures | 43/45 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9292 --w=812 --h=375` |
| 2026-10-19T10:57:53Z | [motion](runs/2026-10-19T10-57-53-227Z-motion/result.json) | complete-pass | 4/4 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/motion.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T10:57:58Z | [axe](runs/2026-10-19T10-57-58-536Z-axe/result.json) | complete-pass | 18/18 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/axe.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T10:58:24Z | [nav](runs/2026-10-19T10-58-24-740Z-nav/result.json) | complete-pass | 31/31 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/nav.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T10:58:57Z | [nav-insets44](runs/2026-10-19T10-58-57-882Z-nav-insets44/result.json) | complete-pass | 31/31 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/nav.mjs --base-url=http://127.0.0.1:9292 --insets=44` |
| 2026-10-19T11:15:12Z | [layout](runs/2026-10-19T11-15-12-122Z-layout/result.json) | complete-with-failures | 213/214 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/layout.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T11:33:51Z | [layout-insets44](runs/2026-10-19T11-33-51-971Z-layout-insets44/result.partial.json) | partial | 77/77 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/layout.mjs --base-url=http://127.0.0.1:9292 --insets=44 --viewports=375x812,812x375,1024x200,768x1024,1440x900,1024x481` |
| 2026-10-19T11:34:44Z | [keyboard](runs/2026-10-19T11-34-44-778Z-keyboard/result.partial.json) | partial | 30/31 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=375x812,440x956,320x640` |
| 2026-10-19T12:16:11Z | [keyboard](runs/2026-10-19T12-16-11-067Z-keyboard/result.partial.json) | partial | 34/37 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=768x1024,1024x768,812x375` |
| 2026-10-19T12:34:29Z | [keyboard](runs/2026-10-19T12-34-29-509Z-keyboard/result.partial.json) | partial | 45/46 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1440x900,1024x200,1024x480,1024x481` |
| 2026-10-19T12:48:23Z | [keyboard-insets44](runs/2026-10-19T12-48-23-434Z-keyboard-insets44/result.partial.json) | partial | 45/45 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --insets=44 --viewports=812x375,375x812,1024x768` |
| 2026-10-19T13:22:19Z | [screens](runs/2026-10-19T13-22-19-002Z-screens/result.json) | complete-with-failures | 93/95 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/screens.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T13:45:15Z | [screens-insets44](runs/2026-10-19T13-45-15-950Z-screens-insets44/result.partial.json) | partial | 23/24 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/screens.mjs --base-url=http://127.0.0.1:9292 --insets=44 --viewports=812x375,375x812` |
| 2026-10-19T14:01:24Z | [negative-control-dock-ring-keyboard](runs/2026-10-19T14-01-24-517Z-negative-control-dock-ring-keyboard/result.partial.json) | partial | 2/3 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=375x812 --pages=collection --label=dock-ring --inject-css=.dock__item:focus-visible{z-index:auto !important}` |
| 2026-10-19T14:01:41Z | [negative-control-thumbs-ring-keyboard](runs/2026-10-19T14-01-41-693Z-negative-control-thumbs-ring-keyboard/result.partial.json) | partial | 2/3 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1440x900 --pages=product --label=thumbs-ring --inject-css=.gallery__thumbs .thumb:focus-visible{outline-offset:2px !important}` |
| 2026-10-19T14:18:46Z | [negative-control-rail-ring-keyboard](runs/2026-10-19T14-18-46-685Z-negative-control-rail-ring-keyboard/result.partial.json) | partial | 2/3 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1440x900 --pages=home --label=rail-ring --inject-css=@media (min-width:1024px){.rail__track{margin-inline:0 !important;padding-inline:0 !important}}` |
| 2026-10-19T14:19:06Z | [negative-control-sidebar-ring-keyboard](runs/2026-10-19T14-19-06-833Z-negative-control-sidebar-ring-keyboard/result.partial.json) | partial | 2/3 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1440x900 --pages=collection --label=sidebar-ring --inject-css=@media (min-width:1200px){.collection-layout--filters .filter-sidebar{margin:0 !important;padding:0 4px 0 0 !important}}` |
| 2026-10-19T14:19:28Z | [negative-control-short-viewport-release-layout](runs/2026-10-19T14-19-28-305Z-negative-control-short-viewport-release-layout/result.partial.json) | partial | 8/12 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/layout.mjs --base-url=http://127.0.0.1:9292 --viewports=1024x200 --label=short-viewport-release --inject-css=@media (max-height:480px){.site-top,.page-bar{position:sticky !important}.product-panel,.cart-layout .summary{position:sticky !important}.gallery__main{max-width:calc((100vh - 146px) * 0.8) !important}}` |
| 2026-10-19T14:20:19Z | [journey-812x375](runs/2026-10-19T14-20-19-889Z-journey-812x375/result.json) | complete-pass | 52/52 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9292 --w=812 --h=375` |
| 2026-10-19T14:20:46Z | [layout](runs/2026-10-19T14-20-46-675Z-layout/result.partial.json) | partial | 10/10 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/layout.mjs --base-url=http://127.0.0.1:9292 --viewports=768x481` |
| 2026-10-19T14:20:55Z | [keyboard](runs/2026-10-19T14-20-55-820Z-keyboard/result.partial.json) | partial | 15/15 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=375x812` |
| 2026-10-19T14:21:59Z | [keyboard](runs/2026-10-19T14-21-59-070Z-keyboard/result.partial.json) | partial | 30/30 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1024x768,812x375` |
| 2026-10-19T14:24:18Z | [keyboard](runs/2026-10-19T14-24-18-425Z-keyboard/result.partial.json) | partial | 15/15 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1024x481` |
| 2026-10-19T14:25:27Z | [screens](runs/2026-10-19T14-25-27-411Z-screens/result.partial.json) | partial | 24/24 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/screens.mjs --base-url=http://127.0.0.1:9292 --viewports=1024x768,320x640` |
| 2026-10-19T14:25:57Z | [screens-insets44](runs/2026-10-19T14-25-57-234Z-screens-insets44/result.partial.json) | partial | 13/13 | monetta-staging.myshopify.com · 192125304866 | `a962cd92f8a4` (610 archivos) | `node docs/web-redesign/shopify-staging/scripts/e2e/screens.mjs --base-url=http://127.0.0.1:9292 --insets=44 --viewports=375x812` |

## Comprobaciones que no pasaron

Todas las de esta lista son **de infraestructura**, no del tema: el proxy local de `shopify theme dev` se volvió lento y dio tiempos de espera (`page.goto`/`page.screenshot` a 30 s), algún 502 y respuestas JSON de error mientras corría la serie del 19/10 (el proxy autenticado ya había caducado una vez con un 401 y se levantó otro; ver ENTREGA §7). Cada una se repitió por separado con la misma orden y el mismo estado del código, y las repeticiones aparecen arriba en verde. Las ejecuciones fallidas se conservan, no se editan.

### journey-812x375 (2026-10-19T10-42-15-755Z-journey-812x375)

- **product — unexpected error** — page.evaluate: SyntaxError: Failed to execute 'json' on 'Response': Unexpected end of JSON input
- **no unexpected console errors or page errors from the theme** — ["console: Failed to load resource: the server responded with a status of 502 (Bad Gateway) @ http://127.0.0.1:9292/products/reloj-coach-talia-saddle.js"]

### layout (2026-10-19T11-15-12-122Z-layout)

- **768×481 — unexpected error** — page.goto: Timeout 30000ms exceeded.

### keyboard (2026-10-19T11-34-44-778Z-keyboard)

- **375×812 — unexpected error** — page.goto: Timeout 30000ms exceeded.

### keyboard (2026-10-19T12-16-11-067Z-keyboard)

- **1024×768 — unexpected error** — page.screenshot: Timeout 30000ms exceeded.
- **812×375 home: 1 tab stops; every centre visible, hit-testable and ring painted** — ["div.json-formatter-container \"json-formatter-container\": no visible focus indicator (outline none, focus-visible false)"]
- **812×375 home: the skip link is the first stop and was not activated** — div.json-formatter-container "json-formatter-container"

### keyboard (2026-10-19T12-34-29-509Z-keyboard)

- **1024×481 — unexpected error** — page.screenshot: Timeout 30000ms exceeded.

### screens (2026-10-19T13-22-19-002Z-screens)

- **1024×768 bag: captured** — page.goto: Timeout 30000ms exceeded.
- **320×640 search: captured** — page.goto: Timeout 30000ms exceeded.

### screens-insets44 (2026-10-19T13-45-15-950Z-screens-insets44)

- **375×812 collection: captured with every visible image loaded and decoded** — ["http://127.0.0.1:9292/cdn/shop/files/guess-crossbody-satchel-beige-cafe-1.jpg?v=1791963929&width=240","http://127.0.0.1:9292/cdn/shop/files/guess-crossbody-satchel-blanco-gris-monograma-35x23x11.jpg?v=1791963905&width=240","http://127.0.0.1:9292/cdn/shop/files/guess-crossbody-satchel-blanco-negro-monograma-35x23x11.jpg?v=1791963906&width=240"]


## Controles negativos (se espera que fallen)

Cada uno reintroduce a propósito, con una hoja de estilos inyectada, un defecto ya corregido (campo `injectCss` del resultado) y comprueba que el verificador lo detecta. **Fallar aquí es el resultado correcto**; que pasara significaría que el verificador no ve ese defecto.

- **negative-control-dock-ring-keyboard** (`runs/2026-10-19T14-01-24-517Z-negative-control-dock-ring-keyboard`): detectado — 1 comprobación(es) fallan. CSS inyectado: `.dock__item:focus-visible{z-index:auto !important}`
  - 375×812 collection: 64 tab stops; every centre visible, hit-testable and ring painted — ["a.dock__item \"Inicio\": focus ring right side not painted (0% of 1 samples dark)"]
- **negative-control-thumbs-ring-keyboard** (`runs/2026-10-19T14-01-41-693Z-negative-control-thumbs-ring-keyboard`): detectado — 1 comprobación(es) fallan. CSS inyectado: `.gallery__thumbs .thumb:focus-visible{outline-offset:2px !important}`
  - 1440×900 product: 57 tab stops; every centre visible, hit-testable and ring painted — ["button.thumb \"Ver foto 1 de 8\": focus ring top side not painted (0% of 3 samples dark)","button.thumb \"Ver foto 1 de 8\": focus ring left side not painted (0% of 3 samples dark)","button.thumb \"Ver foto 1 de 8\": f
- **negative-control-rail-ring-keyboard** (`runs/2026-10-19T14-18-46-685Z-negative-control-rail-ring-keyboard`): detectado — 1 comprobación(es) fallan. CSS inyectado: `@media (min-width:1024px){.rail__track{margin-inline:0 !important;padding-inline:0 !important}}`
  - 1440×900 home: 56 tab stops; every centre visible, hit-testable and ring painted — ["a.card__link \"-21% GuessBolsa Guess Beige y Blanca Hobo Hombro\": focus ring left side not painted (0% of 3 samples dark)","a.card__link \"Envío inmediatoGuessBolsa Guess Crossbody Camera\": focus ring right side not 
- **negative-control-sidebar-ring-keyboard** (`runs/2026-10-19T14-19-06-833Z-negative-control-sidebar-ring-keyboard`): detectado — 1 comprobación(es) fallan. CSS inyectado: `@media (min-width:1200px){.collection-layout--filters .filter-sidebar{margin:0 !important;padding:0 4px 0 0 !important}}`
  - 1440×900 collection: 70 tab stops; every centre visible, hit-testable and ring painted — ["summary. \"Availability\": focus ring top side not painted (0% of 3 samples dark)","summary. \"Availability\": focus ring left side not painted (0% of 3 samples dark)","input. \"filter.v.availability\": focus ring left
- **negative-control-short-viewport-release-layout** (`runs/2026-10-19T14-19-28-305Z-negative-control-short-viewport-release-layout`): detectado — 4 comprobación(es) fallan. CSS inyectado: `@media (max-height:480px){.site-top,.page-bar{position:sticky !important}.product-panel,.cart-layout .summary{position:sticky !important}.gallery__main{max-width:calc((100vh - 146px) * 0.8) !important}}`
  - 1024×200 collection: short viewport releases the top chrome (header group and page bar static, nothing pinned) — siteTop=sticky pageBar=sticky pinnedTop=0
  - 1024×200 product: product panel not sticky, gallery not squeezed (viewer 43×54, panel sticky) — {"viewer":{"position":"relative","display":"block","top":-225.859375,"bottom":-171.875,"height":53.984375,"width":43.1875,"maxHeight":"none","maxWidth":"43.2px"},"panel":"sticky","thumbs":"none"}

## Notas registradas por las ejecuciones

- (journey-375x812) sort select hidden at this width (the phone uses the drawer); sort checked from the drawer in the next block
- (journey-375x812) Available:false variants are accepted by /cart/add.js in this store (probed with the Negro variant of bolso-steve-madden-crossbody-3 and a 5000-unit add on 60 products: no 422). The theme blocks them in the UI by Shopify's `available`; Shopify itself does not.
- (journey-375x812) redirect chain after "Continuar al checkout": 302 /cart -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx | 302 /checkouts/cn/hWNI9ABANmMMUE0FZzGFammI/en-mx -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx; landed on https://monetta-staging.myshopify.com/password
- (journey-375x812) The checkout page itself was not reached: the headless browser has no storefront password for monetta-staging.myshopify.com, which gates the store domain. A signed-in staff browser or a password-holder reaches it. Nothing was entered; no order or payment was made.
- (journey-440x956) sort select hidden at this width (the phone uses the drawer); sort checked from the drawer in the next block
- (journey-440x956) Available:false variants are accepted by /cart/add.js in this store (probed with the Negro variant of bolso-steve-madden-crossbody-3 and a 5000-unit add on 60 products: no 422). The theme blocks them in the UI by Shopify's `available`; Shopify itself does not.
- (journey-440x956) redirect chain after "Continuar al checkout": 302 /cart -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx | 302 /checkouts/cn/hWNI9AEtbaJ0eC81j991pQdG/en-mx -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx; landed on https://monetta-staging.myshopify.com/password
- (journey-440x956) The checkout page itself was not reached: the headless browser has no storefront password for monetta-staging.myshopify.com, which gates the store domain. A signed-in staff browser or a password-holder reaches it. Nothing was entered; no order or payment was made.
- (journey-768x1024) backarrow: the page bar arrow is phone-only (hidden from 768 px); covered at 375/440 widths.
- (journey-768x1024) Available:false variants are accepted by /cart/add.js in this store (probed with the Negro variant of bolso-steve-madden-crossbody-3 and a 5000-unit add on 60 products: no 422). The theme blocks them in the UI by Shopify's `available`; Shopify itself does not.
- (journey-768x1024) redirect chain after "Continuar al checkout": 302 /cart -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx | 302 /checkouts/cn/hWNI9AHdlTXXE5ueUA5N0UoU/en-mx -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx; landed on https://monetta-staging.myshopify.com/password
- (journey-768x1024) The checkout page itself was not reached: the headless browser has no storefront password for monetta-staging.myshopify.com, which gates the store domain. A signed-in staff browser or a password-holder reaches it. Nothing was entered; no order or payment was made.
- (journey-1024x768) backarrow: the page bar arrow is phone-only (hidden from 768 px); covered at 375/440 widths.
- (journey-1024x768) Available:false variants are accepted by /cart/add.js in this store (probed with the Negro variant of bolso-steve-madden-crossbody-3 and a 5000-unit add on 60 products: no 422). The theme blocks them in the UI by Shopify's `available`; Shopify itself does not.
- (journey-1024x768) redirect chain after "Continuar al checkout": 302 /cart -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx | 302 /checkouts/cn/hWNI9AKJFYlq1oab57KSRMzy/en-mx -> https://monetta-staging.myshopify.com | 302 / -> https://monetta-staging.myshopify.com/password; landed on https://monetta-staging.myshopify.com/password
- (journey-1024x768) The checkout page itself was not reached: the headless browser has no storefront password for monetta-staging.myshopify.com, which gates the store domain. A signed-in staff browser or a password-holder reaches it. Nothing was entered; no order or payment was made.
- (journey-1440x900) backarrow: the page bar arrow is phone-only (hidden from 768 px); covered at 375/440 widths.
- (journey-1440x900) Available:false variants are accepted by /cart/add.js in this store (probed with the Negro variant of bolso-steve-madden-crossbody-3 and a 5000-unit add on 60 products: no 422). The theme blocks them in the UI by Shopify's `available`; Shopify itself does not.
- (journey-1440x900) redirect chain after "Continuar al checkout": 302 /cart -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx | 302 /checkouts/cn/hWNI9AN4T2byg58dz7Pw8suQ/en-mx -> https://monetta-staging.myshopify.com | 302 / -> https://monetta-staging.myshopify.com/password; landed on https://monetta-staging.myshopify.com/password
- (journey-1440x900) The checkout page itself was not reached: the headless browser has no storefront password for monetta-staging.myshopify.com, which gates the store domain. A signed-in staff browser or a password-holder reaches it. Nothing was entered; no order or payment was made.
- (journey-812x375) backarrow: the page bar arrow is phone-only (hidden from 768 px); covered at 375/440 widths.
- (journey-812x375) Available:false variants are accepted by /cart/add.js in this store (probed with the Negro variant of bolso-steve-madden-crossbody-3 and a 5000-unit add on 60 products: no 422). The theme blocks them in the UI by Shopify's `available`; Shopify itself does not.
- (journey-812x375) redirect chain after "Continuar al checkout": 302 /cart -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx | 302 /checkouts/cn/hWNI9F3u8Pj5DnjwCdfEdb8s/en-mx -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx; landed on https://monetta-staging.myshopify.com/password
- (journey-812x375) The checkout page itself was not reached: the headless browser has no storefront password for monetta-staging.myshopify.com, which gates the store domain. A signed-in staff browser or a password-holder reaches it. Nothing was entered; no order or payment was made.
- (nav) 1024×768: row overflows with 12 links (desktop: fit-content, no fade)
- (nav) 1440×900: row fits with 12 links (desktop: fit-content, no fade)
- (nav-insets44) 1024×768 +44px insets: row overflows with 12 links (desktop: fit-content, no fade)
- (nav-insets44) 1440×900 +44px insets: row fits with 12 links (desktop: fit-content, no fade)
- (keyboard) 440×956 product: a. "PÁGINA DE PREGUNTAS FRECUENTES" is an inline link that wraps over several lines (merchant content): its ring has no box to sample; visible focus and hit test only
- (keyboard) 320×640 product: a. "PÁGINA DE PREGUNTAS FRECUENTES" is an inline link that wraps over several lines (merchant content): its ring has no box to sample; visible focus and hit test only
- (keyboard) 768×1024 product: a. "PÁGINA DE PREGUNTAS FRECUENTES" is an inline link that wraps over several lines (merchant content): its ring has no box to sample; visible focus and hit test only
- (keyboard-insets44) 375×812 product: a. "PÁGINA DE PREGUNTAS FRECUENTES" is an inline link that wraps over several lines (merchant content): its ring has no box to sample; visible focus and hit test only
- (journey-812x375) redirect chain after "Continuar al checkout": 302 /cart -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx | 302 /checkouts/cn/hWNI9ZcfKHvXrVEZVC7jQATq/en-mx -> https://monetta-staging.myshopify.com/checkouts/cn/<token>/en-mx; landed on https://monetta-staging.myshopify.com/password
