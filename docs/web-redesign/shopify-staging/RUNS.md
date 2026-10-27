# Índice de ejecuciones

Generado por `scripts/runs-index.mjs` a partir de `runs/*/result*.json`; no se edita a mano. Cada fila identifica tienda, tema, estado del código (SHA-256 del árbol de `storefront-theme/`), comando y hora. `complete-*` = ejecución completa; `partial` = subconjunto de tamaños o páginas (nunca se presenta como resultado completo); `partial-error` = el guion terminó con un error. Las ejecuciones de **desarrollo** (`--label=dev…`) se listan pero no cuentan en ninguna cifra.

## Estados del código

| Árbol (SHA-256) | Archivos | Ejecuciones | Qué es |
|---|---|---|---|
| `a962cd92f8a4` | 610 | 30 (25 de verificación) | árbol de la primera entrega, el que auditó Codex. **Histórico**: sus ejecuciones no se atribuyen al código corregido |
| `3952b90ff3ac` | 611 | 2 (0 de verificación) | estado intermedio del código durante las correcciones: sus ejecuciones no cuentan en las cifras |
| `3bc7b18d5486` | 611 | 9 (0 de verificación) | estado intermedio del código durante las correcciones: sus ejecuciones no cuentan en las cifras |
| `10fc869e85c5` | 611 | 3 (1 de verificación) | estado intermedio del código durante las correcciones: sus ejecuciones no cuentan en las cifras |
| `7f5097631058` | 611 | 3 (1 de verificación) | estado intermedio del código durante las correcciones: sus ejecuciones no cuentan en las cifras |
| `f933fdac181a` | 657 | 1 (0 de verificación) | estado intermedio del código durante las correcciones: sus ejecuciones no cuentan en las cifras |
| `c8b43095219c` | 657 | 1 (1 de verificación) | estado intermedio del código durante las correcciones: sus ejecuciones no cuentan en las cifras |
| `0ec94cbfd124` | 657 | 1 (0 de verificación) | estado intermedio del código durante las correcciones: sus ejecuciones no cuentan en las cifras |
| `d3c5f4391fdc` | 657 | 1 (0 de verificación) | estado intermedio del código durante las correcciones: sus ejecuciones no cuentan en las cifras |
| `f5c60cdb01ea` | 657 | 11 (7 de verificación) | **árbol actual, con las correcciones de la auditoría**: el estado de código de las ejecuciones de cierre |

## Ejecuciones

| Hora (UTC) | Ejecución | Propósito | Estado | Checks | Árbol | Comando |
|---|---|---|---|---|---|---|
| 2026-10-19T10:09:05Z | [journey-375x812](runs/2026-10-19T10-09-05-342Z-journey-375x812/result.json) | verificación | complete-pass | 55/55 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=375 --h=812` |
| 2026-10-19T10:09:41Z | [journey-440x956](runs/2026-10-19T10-09-41-366Z-journey-440x956/result.json) | verificación | complete-pass | 55/55 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=440 --h=956` |
| 2026-10-19T10:10:16Z | [journey-768x1024](runs/2026-10-19T10-10-16-537Z-journey-768x1024/result.json) | verificación | complete-pass | 52/52 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=768 --h=1024` |
| 2026-10-19T10:10:42Z | [journey-1024x768](runs/2026-10-19T10-10-42-390Z-journey-1024x768/result.json) | verificación | complete-pass | 52/52 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=1024 --h=768` |
| 2026-10-19T10:11:07Z | [journey-1440x900](runs/2026-10-19T10-11-07-400Z-journey-1440x900/result.json) | verificación | complete-pass | 51/51 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9293 --w=1440 --h=900` |
| 2026-10-19T10:42:15Z | [journey-812x375](runs/2026-10-19T10-42-15-755Z-journey-812x375/result.json) | verificación | complete-with-failures | 43/45 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9292 --w=812 --h=375` |
| 2026-10-19T10:57:53Z | [motion](runs/2026-10-19T10-57-53-227Z-motion/result.json) | verificación | complete-pass | 4/4 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/motion.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T10:57:58Z | [axe](runs/2026-10-19T10-57-58-536Z-axe/result.json) | verificación | complete-pass | 18/18 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/axe.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T10:58:24Z | [nav](runs/2026-10-19T10-58-24-740Z-nav/result.json) | verificación | complete-pass | 31/31 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/nav.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T10:58:57Z | [nav-insets44](runs/2026-10-19T10-58-57-882Z-nav-insets44/result.json) | verificación | complete-pass | 31/31 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/nav.mjs --base-url=http://127.0.0.1:9292 --insets=44` |
| 2026-10-19T11:15:12Z | [layout](runs/2026-10-19T11-15-12-122Z-layout/result.json) | verificación | complete-with-failures | 213/214 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/layout.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T11:33:51Z | [layout-insets44](runs/2026-10-19T11-33-51-971Z-layout-insets44/result.partial.json) | verificación | partial | 77/77 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/layout.mjs --base-url=http://127.0.0.1:9292 --insets=44 --viewports=375x812,812x375,1024x200,768x1024,1440x900,1024x481` |
| 2026-10-19T11:34:44Z | [keyboard](runs/2026-10-19T11-34-44-778Z-keyboard/result.partial.json) | verificación | partial | 30/31 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=375x812,440x956,320x640` |
| 2026-10-19T12:16:11Z | [keyboard](runs/2026-10-19T12-16-11-067Z-keyboard/result.partial.json) | verificación | partial | 34/37 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=768x1024,1024x768,812x375` |
| 2026-10-19T12:34:29Z | [keyboard](runs/2026-10-19T12-34-29-509Z-keyboard/result.partial.json) | verificación | partial | 45/46 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1440x900,1024x200,1024x480,1024x481` |
| 2026-10-19T12:48:23Z | [keyboard-insets44](runs/2026-10-19T12-48-23-434Z-keyboard-insets44/result.partial.json) | verificación | partial | 45/45 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --insets=44 --viewports=812x375,375x812,1024x768` |
| 2026-10-19T13:22:19Z | [screens](runs/2026-10-19T13-22-19-002Z-screens/result.json) | verificación | complete-with-failures | 93/95 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/screens.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-19T13:45:15Z | [screens-insets44](runs/2026-10-19T13-45-15-950Z-screens-insets44/result.partial.json) | verificación | partial | 23/24 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/screens.mjs --base-url=http://127.0.0.1:9292 --insets=44 --viewports=812x375,375x812` |
| 2026-10-19T14:01:24Z | [negative-control-dock-ring-keyboard](runs/2026-10-19T14-01-24-517Z-negative-control-dock-ring-keyboard/result.partial.json) | control negativo | partial | 2/3 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=375x812 --pages=collection --label=dock-ring --inject-css=.dock__item:focus-visible{z-index:auto !important}` |
| 2026-10-19T14:01:41Z | [negative-control-thumbs-ring-keyboard](runs/2026-10-19T14-01-41-693Z-negative-control-thumbs-ring-keyboard/result.partial.json) | control negativo | partial | 2/3 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1440x900 --pages=product --label=thumbs-ring --inject-css=.gallery__thumbs .thumb:focus-visible{outline-offset:2px !important}` |
| 2026-10-19T14:18:46Z | [negative-control-rail-ring-keyboard](runs/2026-10-19T14-18-46-685Z-negative-control-rail-ring-keyboard/result.partial.json) | control negativo | partial | 2/3 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1440x900 --pages=home --label=rail-ring --inject-css=@media (min-width:1024px){.rail__track{margin-inline:0 !important;padding-inline:0 !important}}` |
| 2026-10-19T14:19:06Z | [negative-control-sidebar-ring-keyboard](runs/2026-10-19T14-19-06-833Z-negative-control-sidebar-ring-keyboard/result.partial.json) | control negativo | partial | 2/3 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1440x900 --pages=collection --label=sidebar-ring --inject-css=@media (min-width:1200px){.collection-layout--filters .filter-sidebar{margin:0 !important;padding:0 4px 0 0 !important}}` |
| 2026-10-19T14:19:28Z | [negative-control-short-viewport-release-layout](runs/2026-10-19T14-19-28-305Z-negative-control-short-viewport-release-layout/result.partial.json) | control negativo | partial | 8/12 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/layout.mjs --base-url=http://127.0.0.1:9292 --viewports=1024x200 --label=short-viewport-release --inject-css=@media (max-height:480px){.site-top,.page-bar{position:sticky !important}.product-panel,.cart-layout .summary{position:sticky !important}.gallery__main{max-width:calc((100vh - 146px) * 0.8) !important}}` |
| 2026-10-19T14:20:19Z | [journey-812x375](runs/2026-10-19T14-20-19-889Z-journey-812x375/result.json) | verificación | complete-pass | 52/52 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9292 --w=812 --h=375` |
| 2026-10-19T14:20:46Z | [layout](runs/2026-10-19T14-20-46-675Z-layout/result.partial.json) | verificación | partial | 10/10 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/layout.mjs --base-url=http://127.0.0.1:9292 --viewports=768x481` |
| 2026-10-19T14:20:55Z | [keyboard](runs/2026-10-19T14-20-55-820Z-keyboard/result.partial.json) | verificación | partial | 15/15 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=375x812` |
| 2026-10-19T14:21:59Z | [keyboard](runs/2026-10-19T14-21-59-070Z-keyboard/result.partial.json) | verificación | partial | 30/30 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1024x768,812x375` |
| 2026-10-19T14:24:18Z | [keyboard](runs/2026-10-19T14-24-18-425Z-keyboard/result.partial.json) | verificación | partial | 15/15 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292 --viewports=1024x481` |
| 2026-10-19T14:25:27Z | [screens](runs/2026-10-19T14-25-27-411Z-screens/result.partial.json) | verificación | partial | 24/24 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/screens.mjs --base-url=http://127.0.0.1:9292 --viewports=1024x768,320x640` |
| 2026-10-19T14:25:57Z | [screens-insets44](runs/2026-10-19T14-25-57-234Z-screens-insets44/result.partial.json) | verificación | partial | 13/13 | `a962cd92f8a4` | `node docs/web-redesign/shopify-staging/scripts/e2e/screens.mjs --base-url=http://127.0.0.1:9292 --insets=44 --viewports=375x812` |
| 2026-10-19T22:08:31Z | [regressions-1440x900-dev](runs/2026-10-19T22-08-31-237Z-regressions-1440x900-dev/result.partial.json) | desarrollo | partial | 0/2 | `3952b90ff3ac` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9292 --w=1440 --h=900 --only=p1 --label=dev` |
| 2026-10-19T22:10:08Z | [regressions-1440x900-dev](runs/2026-10-19T22-10-08-495Z-regressions-1440x900-dev/result.partial.json) | desarrollo | partial | 4/5 | `3952b90ff3ac` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9294 --w=1440 --h=900 --only=p1 --label=dev` |
| 2026-10-19T22:11:37Z | [regressions-1440x900-dev](runs/2026-10-19T22-11-37-293Z-regressions-1440x900-dev/result.partial.json) | desarrollo | partial | 4/5 | `3bc7b18d5486` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9294 --w=1440 --h=900 --only=p1 --label=dev` |
| 2026-10-19T22:12:38Z | [regressions-1440x900-dev](runs/2026-10-19T22-12-38-927Z-regressions-1440x900-dev/result.partial.json) | desarrollo | partial | 40/40 | `3bc7b18d5486` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9294 --w=1440 --h=900 --only=p1 --label=dev` |
| 2026-10-19T22:13:30Z | [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-13-30-149Z-negative-control-1440x900-dev-oldp1/result.partial.json) | control (desarrollo) | partial | 1/2 | `3bc7b18d5486` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9294 --w=1440 --h=900 --only=p1 --label=dev-oldp1 --old-assets=monetta-product.js,monetta-cart.js --expect=P1 [staging] slow answer: the page reports the choice as pending\|P1 [staging] slow answer: every add button is really disabled\|P1 [staging] slow answer: pressing every add button\|P1 [staging] HTTP 503: the chips, the header value, the id and the address go back` |
| 2026-10-19T22:14:02Z | [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-14-02-524Z-negative-control-1440x900-dev-oldp1/result.partial.json) | control (desarrollo) | partial | 1/2 | `3bc7b18d5486` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9294 --w=1440 --h=900 --only=p1 --label=dev-oldp1 --old-assets=monetta-product.js,monetta-cart.js --expect=P1 [staging] slow answer: the page reports the choice as pending\|P1 [staging] slow answer: every add button is really disabled\|P1 [staging] slow answer: pressing every add button\|P1 [staging] HTTP 503: the chips, the header value, the id and the address go back` |
| 2026-10-19T22:14:34Z | [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-14-34-320Z-negative-control-1440x900-dev-oldp1/result.partial.json) | control (desarrollo) | partial | 3/13 | `3bc7b18d5486` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9294 --w=1440 --h=900 --only=p1 --label=dev-oldp1 --old-assets=monetta-product.js,monetta-cart.js --expect=P1 [staging] slow answer: the page reports the choice as pending\|P1 [staging] slow answer: every add button is really disabled\|P1 [staging] slow answer: pressing every add button\|P1 [staging] HTTP 503: the chips, the header value, the id and the address go back` |
| 2026-10-19T22:15:18Z | [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-15-18-348Z-negative-control-1440x900-dev-oldp1/result.partial.json) | control (desarrollo) | partial | 3/16 | `3bc7b18d5486` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9294 --w=1440 --h=900 --only=p1 --label=dev-oldp1 --old-assets=monetta-product.js,monetta-cart.js --expect=P1 [staging] slow answer: the page reports the choice as pending\|P1 [staging] slow answer: every add button is really disabled\|P1 [staging] slow answer: pressing every add button\|P1 [staging] HTTP 503: the chips, the header value, the id and the address go back` |
| 2026-10-19T22:16:19Z | [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-16-19-869Z-negative-control-1440x900-dev-oldp1/result.partial.json) | control (desarrollo) | partial | 2/28 | `3bc7b18d5486` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9294 --w=1440 --h=900 --only=p1 --label=dev-oldp1 --old-assets=monetta-product.js,monetta-cart.js --expect=P1 [staging] slow answer: the page reports the choice as pending\|P1 [staging] slow answer: every add button is really disabled\|P1 [staging] slow answer: pressing every add button\|P1 [staging] HTTP 503: the chips, the header value, the id and the address go back` |
| 2026-10-19T22:18:17Z | [regressions-1440x900-dev](runs/2026-10-19T22-18-17-923Z-regressions-1440x900-dev/result.partial.json) | desarrollo | partial | 42/43 | `3bc7b18d5486` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9292 --w=1440 --h=900 --only=p3,p4,p5,p6,p8 --label=dev` |
| 2026-10-19T22:19:50Z | [regressions-1440x900-dev](runs/2026-10-19T22-19-50-710Z-regressions-1440x900-dev/result.partial.json) | desarrollo | partial | 38/38 | `3bc7b18d5486` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9292 --w=1440 --h=900 --only=p2,p7 --label=dev` |
| 2026-10-19T22:25:41Z | [regressions-375x812-dev](runs/2026-10-19T22-25-41-202Z-regressions-375x812-dev/result.json) | desarrollo | complete-with-failures | 120/121 | `10fc869e85c5` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9292 --w=375 --h=812 --label=dev` |
| 2026-10-19T22:27:34Z | [regressions-375x812-dev](runs/2026-10-19T22-27-34-006Z-regressions-375x812-dev/result.partial.json) | desarrollo | partial | 8/8 | `10fc869e85c5` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9292 --w=375 --h=812 --only=p3 --label=dev` |
| 2026-10-19T22:28:28Z | [states-375x812](runs/2026-10-19T22-28-28-752Z-states-375x812/result.json) | verificación | complete-pass | 12/12 | `10fc869e85c5` | `node docs/web-redesign/shopify-staging/scripts/e2e/states.mjs --base-url=http://127.0.0.1:9292 --w=375 --h=812` |
| 2026-10-19T22:29:46Z | [regressions-1440x900-dev](runs/2026-10-19T22-29-46-054Z-regressions-1440x900-dev/result.partial.json) | desarrollo | partial | 42/42 | `7f5097631058` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9292 --w=1440 --h=900 --only=p1 --label=dev` |
| 2026-10-19T22:30:12Z | [regressions-1440x900-dev](runs/2026-10-19T22-30-12-779Z-regressions-1440x900-dev/result.partial.json) | desarrollo | partial | 42/42 | `7f5097631058` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9292 --w=1440 --h=900 --only=p1 --label=dev` |
| 2026-10-19T22:33:40Z | [journey-440x956](runs/2026-10-19T22-33-40-926Z-journey-440x956/result.json) | verificación | complete-with-failures | 16/23 | `7f5097631058` | `node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9292 --w=440 --h=956` |
| 2026-10-22T22:45:45Z | [dl-checks-dev](runs/2026-10-22T22-45-45-948Z-dl-checks-dev/result.json) | desarrollo | complete-with-failures | 57/58 | `f933fdac181a` | `node docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/checks.mjs --base-url=http://127.0.0.1:9292 --viewports=390x844 --flows --name=dl-checks-dev` |
| 2026-10-22T22:47:40Z | [dl-checks](runs/2026-10-22T22-47-40-579Z-dl-checks/result.json) | verificación | complete-with-failures | 286/290 | `c8b43095219c` | `node docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/checks.mjs --base-url=http://127.0.0.1:9292 --flows --name=dl-checks` |
| 2026-10-22T22:52:25Z | [dl-checks-dev](runs/2026-10-22T22-52-25-244Z-dl-checks-dev/result.json) | desarrollo | complete-with-failures | 98/114 | `0ec94cbfd124` | `node docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/checks.mjs --base-url=http://127.0.0.1:9292 --viewports=390x844,1440x900 --name=dl-checks-dev` |
| 2026-10-22T22:54:06Z | [dl-checks-dev](runs/2026-10-22T22-54-06-912Z-dl-checks-dev/result.json) | desarrollo | complete-with-failures | 98/114 | `d3c5f4391fdc` | `node docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/checks.mjs --base-url=http://127.0.0.1:9292 --viewports=390x844,1024x768 --name=dl-checks-dev` |
| 2026-10-22T22:56:39Z | [dl-checks](runs/2026-10-22T22-56-39-216Z-dl-checks/result.json) | verificación | complete-pass | 330/330 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/checks.mjs --base-url=http://127.0.0.1:9292 --flows --name=dl-checks` |
| 2026-10-22T22:59:08Z | [negative-control-dl-blanket-serif](runs/2026-10-22T22-59-08-001Z-negative-control-dl-blanket-serif/result.json) | control negativo | complete-with-failures | 53/57 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/checks.mjs --base-url=http://127.0.0.1:9292 --viewports=390x844 --name=negative-control-dl-blanket-serif --inject-css=.mw :is(h1,h2,h3,h4,h5,h6){font-family:var(--font-serif) !important}` |
| 2026-10-22T22:59:27Z | [negative-control-dl-single-gallery](runs/2026-10-22T22-59-27-051Z-negative-control-dl-single-gallery/result.json) | control negativo | complete-with-failures | 56/57 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/checks.mjs --base-url=http://127.0.0.1:9292 --viewports=1440x900 --name=negative-control-dl-single-gallery --inject-css=@media (min-width:1024px){.gallery--single{display:grid !important}}` |
| 2026-10-22T22:59:48Z | [negative-control-dl-discount-overflow](runs/2026-10-22T22-59-48-962Z-negative-control-dl-discount-overflow/result.json) | control negativo | complete-with-failures | 56/57 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/checks.mjs --base-url=http://127.0.0.1:9292 --viewports=320x640 --name=negative-control-dl-discount-overflow --inject-css=.discount-form input{width:auto !important}.discount-form__row{display:flex !important}` |
| 2026-10-22T23:00:06Z | [negative-control-dl-fav-40](runs/2026-10-22T23-00-06-676Z-negative-control-dl-fav-40/result.json) | control negativo | complete-with-failures | 52/57 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/design-language-2026-10-22/scripts/checks.mjs --base-url=http://127.0.0.1:9292 --viewports=390x844 --name=negative-control-dl-fav-40 --inject-css=.mw .card__fav{width:40px !important;height:40px !important}` |
| 2026-10-22T23:02:19Z | [axe](runs/2026-10-22T23-02-19-335Z-axe/result.json) | verificación | complete-pass | 18/18 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/scripts/e2e/axe.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-22T23:02:54Z | [motion](runs/2026-10-22T23-02-54-795Z-motion/result.json) | verificación | complete-pass | 4/4 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/scripts/e2e/motion.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-22T23:03:00Z | [nav](runs/2026-10-22T23-03-00-088Z-nav/result.json) | verificación | complete-pass | 31/31 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/scripts/e2e/nav.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-22T23:03:35Z | [keyboard](runs/2026-10-22T23-03-35-049Z-keyboard/result.json) | verificación | complete-with-failures | 147/150 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-22T23:19:18Z | [layout](runs/2026-10-22T23-19-18-697Z-layout/result.json) | verificación | complete-with-failures | 214/219 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/scripts/e2e/layout.mjs --base-url=http://127.0.0.1:9292` |
| 2026-10-22T23:21:56Z | [regressions-1440x900](runs/2026-10-22T23-21-56-222Z-regressions-1440x900/result.json) | verificación | complete-with-failures | 121/123 | `f5c60cdb01ea` | `node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9292` |

## Cifras verificadas, sin duplicar por los reintentos

Cada comprobación (verificador + ejecución + nombre) cuenta una vez, con el resultado de su última ejecución sobre ese árbol; un reintento que repite una comprobación fallida la sustituye, no se suma. Se excluyen controles negativos y ejecuciones de desarrollo.

**Árbol `a962cd92f8a4`** (histórico, primera entrega)

| Verificador | Comprobaciones únicas | Aprobadas | No aprobadas | Ejecuciones que lo componen |
|---|---|---|---|---|
| axe | 18 | 18 | 0 | axe |
| journey | 318 | 317 | 1 | journey-1024x768, journey-1440x900, journey-375x812, journey-440x956, journey-768x1024, journey-812x375 |
| keyboard | 200 | 196 | 4 | keyboard, keyboard-insets44 |
| layout | 297 | 296 | 1 | layout, layout-insets44 |
| motion | 4 | 4 | 0 | motion |
| nav | 62 | 62 | 0 | nav, nav-insets44 |
| screens | 121 | 119 | 2 | screens, screens-insets44 |
| **total** | **1020** | **1012** | **8** | |

**Árbol `f5c60cdb01ea`**

| Verificador | Comprobaciones únicas | Aprobadas | No aprobadas | Ejecuciones que lo componen |
|---|---|---|---|---|
| axe | 18 | 18 | 0 | axe |
| keyboard | 150 | 147 | 3 | keyboard |
| layout | 219 | 214 | 5 | layout |
| motion | 4 | 4 | 0 | motion |
| nav | 31 | 31 | 0 | nav |
| regressions | 123 | 121 | 2 | regressions-1440x900 |
| unknown | 330 | 330 | 0 | dl-checks |
| **total** | **875** | **865** | **10** | |

## Comprobaciones que no pasaron

Cada fallo lleva su **síntoma** (lo que dice su propio texto), su **causa** (`determinada` solo si la ejecución registró la evidencia; si no, `no determinada`), la **evidencia** y la **repetición** que repite esa misma comprobación sobre el mismo árbol de código. Las ejecuciones fallidas se conservan, no se editan.

### [journey-812x375](runs/2026-10-19T10-42-15-755Z-journey-812x375/result.json) — 2026-10-19T10:42:15Z, árbol `a962cd92f8a4`

- **product — unexpected error**
  - síntoma: respuesta vacía o no JSON
  - causa: no determinada — síntoma compatible con el proxy (respuesta vacía o no JSON), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `page.evaluate: SyntaxError: Failed to execute 'json' on 'Response': Unexpected end of JSON input`
  - repetición equivalente: [journey-812x375](runs/2026-10-19T14-20-19-889Z-journey-812x375/result.json) (2026-10-19T14:20:19Z, la misma comprobación pasó con el mismo árbol)
- **no unexpected console errors or page errors from the theme**
  - síntoma: respuesta 502
  - causa: no determinada — síntoma compatible con el proxy (respuesta 502), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `["console: Failed to load resource: the server responded with a status of 502 (Bad Gateway) @ http://127.0.0.1:9292/products/reloj-coach-talia-saddle.js"]`
  - repetición equivalente: [journey-812x375](runs/2026-10-19T14-20-19-889Z-journey-812x375/result.json) (2026-10-19T14:20:19Z, la misma comprobación pasó con el mismo árbol)

### [layout](runs/2026-10-19T11-15-12-122Z-layout/result.json) — 2026-10-19T11:15:12Z, árbol `a962cd92f8a4`

- **768×481 — unexpected error**
  - síntoma: tiempo de espera agotado
  - causa: no determinada — síntoma compatible con el proxy (tiempo de espera agotado), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `page.goto: Timeout 30000ms exceeded.`
  - repetición equivalente: [layout](runs/2026-10-19T14-20-46-675Z-layout/result.partial.json) (2026-10-19T14:20:46Z, la misma comprobación pasó con el mismo árbol)

### [keyboard](runs/2026-10-19T11-34-44-778Z-keyboard/result.partial.json) — 2026-10-19T11:34:44Z, árbol `a962cd92f8a4`

- **375×812 — unexpected error**
  - síntoma: tiempo de espera agotado
  - causa: no determinada — síntoma compatible con el proxy (tiempo de espera agotado), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `page.goto: Timeout 30000ms exceeded.`
  - repetición equivalente: [keyboard](runs/2026-10-19T14-20-55-820Z-keyboard/result.partial.json) (2026-10-19T14:20:55Z, la misma comprobación pasó con el mismo árbol)

### [keyboard](runs/2026-10-19T12-16-11-067Z-keyboard/result.partial.json) — 2026-10-19T12:16:11Z, árbol `a962cd92f8a4`

- **1024×768 — unexpected error**
  - síntoma: tiempo de espera agotado
  - causa: no determinada — síntoma compatible con el proxy (tiempo de espera agotado), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `page.screenshot: Timeout 30000ms exceeded.`
  - repetición equivalente: [keyboard](runs/2026-10-19T14-21-59-070Z-keyboard/result.partial.json) (2026-10-19T14:21:59Z, la misma comprobación pasó con el mismo árbol)
- **812×375 home: 1 tab stops; every centre visible, hit-testable and ring painted**
  - síntoma: el documento servido no era el tema (visor JSON del navegador)
  - causa: no determinada — síntoma compatible con el proxy (el documento servido no era el tema (visor JSON del navegador)), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `["div.json-formatter-container \"json-formatter-container\": no visible focus indicator (outline none, focus-visible false)"]`
  - repetición equivalente: [keyboard](runs/2026-10-19T14-21-59-070Z-keyboard/result.partial.json) (2026-10-19T14:21:59Z, la misma comprobación pasó con el mismo árbol)
- **812×375 home: the skip link is the first stop and was not activated**
  - síntoma: el documento servido no era el tema (visor JSON del navegador)
  - causa: no determinada — síntoma compatible con el proxy (el documento servido no era el tema (visor JSON del navegador)), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `div.json-formatter-container "json-formatter-container"`
  - repetición equivalente: [keyboard](runs/2026-10-19T14-21-59-070Z-keyboard/result.partial.json) (2026-10-19T14:21:59Z, la misma comprobación pasó con el mismo árbol)

### [keyboard](runs/2026-10-19T12-34-29-509Z-keyboard/result.partial.json) — 2026-10-19T12:34:29Z, árbol `a962cd92f8a4`

- **1024×481 — unexpected error**
  - síntoma: tiempo de espera agotado
  - causa: no determinada — síntoma compatible con el proxy (tiempo de espera agotado), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `page.screenshot: Timeout 30000ms exceeded.`
  - repetición equivalente: [keyboard](runs/2026-10-19T14-24-18-425Z-keyboard/result.partial.json) (2026-10-19T14:24:18Z, la misma comprobación pasó con el mismo árbol)

### [screens](runs/2026-10-19T13-22-19-002Z-screens/result.json) — 2026-10-19T13:22:19Z, árbol `a962cd92f8a4`

- **1024×768 bag: captured**
  - síntoma: tiempo de espera agotado
  - causa: no determinada — síntoma compatible con el proxy (tiempo de espera agotado), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `page.goto: Timeout 30000ms exceeded.`
  - repetición equivalente: [screens](runs/2026-10-19T14-25-27-411Z-screens/result.partial.json) (2026-10-19T14:25:27Z, la misma comprobación pasó con el mismo árbol)
- **320×640 search: captured**
  - síntoma: tiempo de espera agotado
  - causa: no determinada — síntoma compatible con el proxy (tiempo de espera agotado), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `page.goto: Timeout 30000ms exceeded.`
  - repetición equivalente: [screens](runs/2026-10-19T14-25-27-411Z-screens/result.partial.json) (2026-10-19T14:25:27Z, la misma comprobación pasó con el mismo árbol)

### [screens-insets44](runs/2026-10-19T13-45-15-950Z-screens-insets44/result.partial.json) — 2026-10-19T13:45:15Z, árbol `a962cd92f8a4`

- **375×812 collection: captured with every visible image loaded and decoded**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `["http://127.0.0.1:9292/cdn/shop/files/guess-crossbody-satchel-beige-cafe-1.jpg?v=1791963929&width=240","http://127.0.0.1:9292/cdn/shop/files/guess-crossbody-satchel-blanco-gris-monograma-35x23x11.jpg?v=1791963905&width=240","http://127.0.0.1:9292/cdn/shop/files/guess-crossbody-satchel-blanco-negro-`
  - repetición equivalente: [screens-insets44](runs/2026-10-19T14-25-57-234Z-screens-insets44/result.partial.json) (2026-10-19T14:25:57Z, la misma comprobación pasó con el mismo árbol)

### [journey-440x956](runs/2026-10-19T22-33-40-926Z-journey-440x956/result.json) — 2026-10-19T22:33:40Z, árbol `7f5097631058`

- **home — unexpected error**
  - síntoma: tiempo de espera agotado
  - causa: no determinada — síntoma compatible con el proxy (tiempo de espera agotado), pero la ejecución no registró la petición ni su respuesta; ENTREGA §7 documenta 401/502/timeouts del proxy en esa franja sin atribuirlos a un fallo concreto
  - evidencia: `page.screenshot: Timeout 30000ms exceeded.`
  - repetición equivalente: sin repetición equivalente
- **backarrow — unexpected error**
  - síntoma: error del guion (la comprobación no pudo ejecutarse)
  - causa: no determinada — el guion falló antes de poder evaluar la aserción y no registró una causa
  - evidencia: `locator.click: Target page, context or browser has been closed`
  - repetición equivalente: sin repetición equivalente
- **product — unexpected error**
  - síntoma: error del guion (la comprobación no pudo ejecutarse)
  - causa: no determinada — el guion falló antes de poder evaluar la aserción y no registró una causa
  - evidencia: `page.goto: Target page, context or browser has been closed`
  - repetición equivalente: sin repetición equivalente
- **add — unexpected error**
  - síntoma: error del guion (la comprobación no pudo ejecutarse)
  - causa: no determinada — el guion falló antes de poder evaluar la aserción y no registró una causa
  - evidencia: `page.goto: Target page, context or browser has been closed`
  - repetición equivalente: sin repetición equivalente
- **refusal — unexpected error**
  - síntoma: error del guion (la comprobación no pudo ejecutarse)
  - causa: no determinada — el guion falló antes de poder evaluar la aserción y no registró una causa
  - evidencia: `page.evaluate: Target page, context or browser has been closed`
  - repetición equivalente: sin repetición equivalente
- **bag — unexpected error**
  - síntoma: error del guion (la comprobación no pudo ejecutarse)
  - causa: no determinada — el guion falló antes de poder evaluar la aserción y no registró una causa
  - evidencia: `page.goto: Target page, context or browser has been closed`
  - repetición equivalente: sin repetición equivalente
- **checkout — unexpected error**
  - síntoma: error del guion (la comprobación no pudo ejecutarse)
  - causa: no determinada — el guion falló antes de poder evaluar la aserción y no registró una causa
  - evidencia: `page.goto: Target page, context or browser has been closed`
  - repetición equivalente: sin repetición equivalente

### [dl-checks](runs/2026-10-22T22-47-40-579Z-dl-checks/result.json) — 2026-10-22T22:47:40Z, árbol `c8b43095219c`

- **320×640 contact: no horizontal overflow**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `{"scrollWidth":377,"clientWidth":320}`
  - repetición equivalente: sin repetición equivalente
- **768×1024 contact: no horizontal overflow**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `{"scrollWidth":784,"clientWidth":768}`
  - repetición equivalente: sin repetición equivalente
- **1024×768 home: header icon buttons are at least 48 x 48**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `[{"label":"Ver guardados","w":46,"h":48},{"label":"Cuenta","w":104,"h":48},{"label":"Carrito, vacío","w":101,"h":48}]`
  - repetición equivalente: sin repetición equivalente
- **1440×900 home: header icon buttons are at least 48 x 48**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `[{"label":"Ver guardados","w":46,"h":48},{"label":"Cuenta","w":104,"h":48},{"label":"Carrito, vacío","w":101,"h":48}]`
  - repetición equivalente: sin repetición equivalente

### [keyboard](runs/2026-10-22T23-03-35-049Z-keyboard/result.json) — 2026-10-22T23:03:35Z, árbol `f5c60cdb01ea`

- **375×812 home: 77 tab stops; every centre visible, hit-testable and ring painted**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `["a. \"Totes\": focus ring left side not painted (0% of 3 samples dark)","a. \"De hombro\": focus ring left side not painted (0% of 3 samples dark)"]`
  - repetición equivalente: sin repetición equivalente
- **440×956 home: 77 tab stops; every centre visible, hit-testable and ring painted**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `["a. \"Totes\": focus ring left side not painted (0% of 3 samples dark)"]`
  - repetición equivalente: sin repetición equivalente
- **320×640 home: 77 tab stops; every centre visible, hit-testable and ring painted**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `["a. \"Totes\": focus ring left side not painted (0% of 3 samples dark)","a. \"De hombro\": focus ring left side not painted (0% of 3 samples dark)"]`
  - repetición equivalente: sin repetición equivalente

### [layout](runs/2026-10-22T23-19-18-697Z-layout/result.json) — 2026-10-22T23:19:18Z, árbol `f5c60cdb01ea`

- **375×812 recommendations (phone): heading Inter 17px/600**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `["23px","400","\"Playfair Display\""]`
  - repetición equivalente: sin repetición equivalente
- **440×956 recommendations (phone): heading Inter 17px/600**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `["23px","400","\"Playfair Display\""]`
  - repetición equivalente: sin repetición equivalente
- **320×640 recommendations (phone): heading Inter 17px/600**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `["23px","400","\"Playfair Display\""]`
  - repetición equivalente: sin repetición equivalente
- **360×480 recommendations (phone): heading Inter 17px/600**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `["23px","400","\"Playfair Display\""]`
  - repetición equivalente: sin repetición equivalente
- **360×481 recommendations (phone): heading Inter 17px/600**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `["23px","400","\"Playfair Display\""]`
  - repetición equivalente: sin repetición equivalente

### [regressions-1440x900](runs/2026-10-22T23-21-56-222Z-regressions-1440x900/result.json) — 2026-10-22T23:21:56Z, árbol `f5c60cdb01ea`

- **P8 [staging] fragments Shopify writes in the store's language are marked with it: menu titles and the accelerated checkout**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `{"storeLang":"en","nav":[["Inicio",null],["Catálogo",null],["Contacto",null]],"pay":"en","payText":"Buy it now"}`
  - repetición equivalente: sin repetición equivalente
- **proxy: after the run it still serves the expected theme with the local scripts (checked with bounded waits)**
  - síntoma: aserción fallida
  - causa: determinada — la aserción se evaluó y no se cumplió: el detalle es la evidencia
  - evidencia: `[{"name":"exactly one healthy theme dev proxy exists, it serves the authorised draft theme and it is the one under test","pass":false,"detail":"[[9292,\"192125304866\",\"healthy\"],[9292,\"192125304866\",\"healthy\"]]"}]`
  - repetición equivalente: sin repetición equivalente

## Controles negativos (se espera que fallen)

Cada control reintroduce a propósito un defecto (hoja de estilos inyectada, documento reescrito o guion previo servido) y declara qué aserción concreta debe fallar. **Solo cuenta como detectado** si esa aserción falló como aserción, sin error del guion y sin que el fallo sea un tiempo de espera o una página de error; un fallo cualquiera, una ejecución incompleta o un error no bastan.

- **negative-control-dock-ring-keyboard** ([negative-control-dock-ring-keyboard](runs/2026-10-19T14-01-24-517Z-negative-control-dock-ring-keyboard/result.partial.json), árbol `a962cd92f8a4`): **detectado** — 1 aserción(es) esperada(s) fallaron como aserciones. CSS inyectado: `.dock__item:focus-visible{z-index:auto !important}`
  - 375×812 collection: 64 tab stops; every centre visible, hit-testable and ring painted — ["a.dock__item \"Inicio\": focus ring right side not painted (0% of 1 samples dark)"]
- **negative-control-thumbs-ring-keyboard** ([negative-control-thumbs-ring-keyboard](runs/2026-10-19T14-01-41-693Z-negative-control-thumbs-ring-keyboard/result.partial.json), árbol `a962cd92f8a4`): **detectado** — 1 aserción(es) esperada(s) fallaron como aserciones. CSS inyectado: `.gallery__thumbs .thumb:focus-visible{outline-offset:2px !important}`
  - 1440×900 product: 57 tab stops; every centre visible, hit-testable and ring painted — ["button.thumb \"Ver foto 1 de 8\": focus ring top side not painted (0% of 3 samples dark)","button.thumb \"Ver foto 1 de 8\": focus ring left side not painted (0% of 3 samples dark)","button.thumb \"
- **negative-control-rail-ring-keyboard** ([negative-control-rail-ring-keyboard](runs/2026-10-19T14-18-46-685Z-negative-control-rail-ring-keyboard/result.partial.json), árbol `a962cd92f8a4`): **detectado** — 1 aserción(es) esperada(s) fallaron como aserciones. CSS inyectado: `@media (min-width:1024px){.rail__track{margin-inline:0 !important;padding-inline:0 !important}}`
  - 1440×900 home: 56 tab stops; every centre visible, hit-testable and ring painted — ["a.card__link \"-21% GuessBolsa Guess Beige y Blanca Hobo Hombro\": focus ring left side not painted (0% of 3 samples dark)","a.card__link \"Envío inmediatoGuessBolsa Guess Crossbody Camera\": focus 
- **negative-control-sidebar-ring-keyboard** ([negative-control-sidebar-ring-keyboard](runs/2026-10-19T14-19-06-833Z-negative-control-sidebar-ring-keyboard/result.partial.json), árbol `a962cd92f8a4`): **detectado** — 1 aserción(es) esperada(s) fallaron como aserciones. CSS inyectado: `@media (min-width:1200px){.collection-layout--filters .filter-sidebar{margin:0 !important;padding:0 4px 0 0 !important}}`
  - 1440×900 collection: 70 tab stops; every centre visible, hit-testable and ring painted — ["summary. \"Availability\": focus ring top side not painted (0% of 3 samples dark)","summary. \"Availability\": focus ring left side not painted (0% of 3 samples dark)","input. \"filter.v.availabilit
- **negative-control-short-viewport-release-layout** ([negative-control-short-viewport-release-layout](runs/2026-10-19T14-19-28-305Z-negative-control-short-viewport-release-layout/result.partial.json), árbol `a962cd92f8a4`): **detectado** — 4 aserción(es) esperada(s) fallaron como aserciones. CSS inyectado: `@media (max-height:480px){.site-top,.page-bar{position:sticky !important}.product-panel,.cart-layout .summary{position:s`
  - 1024×200 collection: short viewport releases the top chrome (header group and page bar static, nothing pinned) — siteTop=sticky pageBar=sticky pinnedTop=0
  - 1024×200 product: product panel not sticky, gallery not squeezed (viewer 43×54, panel sticky) — {"viewer":{"position":"relative","display":"block","top":-225.859375,"bottom":-171.875,"height":53.984375,"width":43.1875,"maxHeight":"none","maxWidth":"43.2px"},"panel":"sticky","thumbs":"none"}
- **negative-control-dl-blanket-serif** ([negative-control-dl-blanket-serif](runs/2026-10-22T22-59-08-001Z-negative-control-dl-blanket-serif/result.json), árbol `f5c60cdb01ea`): **NO detectado / no verificable** — no hay una aserción esperada registrada para este control. CSS inyectado: `.mw :is(h1,h2,h3,h4,h5,h6){font-family:var(--font-serif) !important}`
  - 390×844 footer: column labels are the Inter eyebrow, not the serif — {"family":"Playfair Display","size":12,"weight":"600","transform":"uppercase","radius":0,"width":350,"height":18.59375,"left":20,"right":370,"top":4024.59375,"bottom":4043.1875,"text":"Comprar"}
  - 390×844 collection: product-card name is Inter (card-label role, the documented exception) — {"family":"Playfair Display","size":14,"weight":"400","transform":"none","radius":0,"width":165,"height":36.375,"left":12,"right":177,"top":343.75,"bottom":380.125,"text":"Bolsa Guess Beige y Blanca H
- **negative-control-dl-single-gallery** ([negative-control-dl-single-gallery](runs/2026-10-22T22-59-27-051Z-negative-control-dl-single-gallery/result.json), árbol `f5c60cdb01ea`): **NO detectado / no verificable** — no hay una aserción esperada registrada para este control. CSS inyectado: `@media (min-width:1024px){.gallery--single{display:grid !important}}`
  - 1440×900 product (one photo): the viewer keeps a real width — {"width":72}
- **negative-control-dl-discount-overflow** ([negative-control-dl-discount-overflow](runs/2026-10-22T22-59-48-962Z-negative-control-dl-discount-overflow/result.json), árbol `f5c60cdb01ea`): **NO detectado / no verificable** — no hay una aserción esperada registrada para este control. CSS inyectado: `.discount-form input{width:auto !important}.discount-form__row{display:flex !important}`
  - 320×640 bag: no horizontal overflow — {"scrollWidth":382,"clientWidth":320}
- **negative-control-dl-fav-40** ([negative-control-dl-fav-40](runs/2026-10-22T23-00-06-676Z-negative-control-dl-fav-40/result.json), árbol `f5c60cdb01ea`): **NO detectado / no verificable** — no hay una aserción esperada registrada para este control. CSS inyectado: `.mw .card__fav{width:40px !important;height:40px !important}`
  - 390×844 home: every tap target is at least 48px (inline/legal text links excepted) — {"small":["button.card__fav \"Guardar Bolso Steve Madden Shoulder Negr\" 40x40","button.card__fav \"Guardar Bolso Steve Madden Flap Crossbod\" 40x40","button.card__fav \"Guardar Crossbody Steve Madden
  - 390×844 collection: favourite target is 48 x 48 — {"w":40,"h":40}

## Ejecuciones de desarrollo (no cuentan)

- [regressions-1440x900-dev](runs/2026-10-19T22-08-31-237Z-regressions-1440x900-dev/result.partial.json) — 0/2, partial
- [regressions-1440x900-dev](runs/2026-10-19T22-10-08-495Z-regressions-1440x900-dev/result.partial.json) — 4/5, partial
- [regressions-1440x900-dev](runs/2026-10-19T22-11-37-293Z-regressions-1440x900-dev/result.partial.json) — 4/5, partial
- [regressions-1440x900-dev](runs/2026-10-19T22-12-38-927Z-regressions-1440x900-dev/result.partial.json) — 40/40, partial
- [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-13-30-149Z-negative-control-1440x900-dev-oldp1/result.partial.json) — 1/2, partial
- [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-14-02-524Z-negative-control-1440x900-dev-oldp1/result.partial.json) — 1/2, partial
- [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-14-34-320Z-negative-control-1440x900-dev-oldp1/result.partial.json) — 3/13, partial
- [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-15-18-348Z-negative-control-1440x900-dev-oldp1/result.partial.json) — 3/16, partial
- [negative-control-1440x900-dev-oldp1](runs/2026-10-19T22-16-19-869Z-negative-control-1440x900-dev-oldp1/result.partial.json) — 2/28, partial
- [regressions-1440x900-dev](runs/2026-10-19T22-18-17-923Z-regressions-1440x900-dev/result.partial.json) — 42/43, partial
- [regressions-1440x900-dev](runs/2026-10-19T22-19-50-710Z-regressions-1440x900-dev/result.partial.json) — 38/38, partial
- [regressions-375x812-dev](runs/2026-10-19T22-25-41-202Z-regressions-375x812-dev/result.json) — 120/121, complete-with-failures
- [regressions-375x812-dev](runs/2026-10-19T22-27-34-006Z-regressions-375x812-dev/result.partial.json) — 8/8, partial
- [regressions-1440x900-dev](runs/2026-10-19T22-29-46-054Z-regressions-1440x900-dev/result.partial.json) — 42/42, partial
- [regressions-1440x900-dev](runs/2026-10-19T22-30-12-779Z-regressions-1440x900-dev/result.partial.json) — 42/42, partial
- [dl-checks-dev](runs/2026-10-22T22-45-45-948Z-dl-checks-dev/result.json) — 57/58, complete-with-failures
- [dl-checks-dev](runs/2026-10-22T22-52-25-244Z-dl-checks-dev/result.json) — 98/114, complete-with-failures
- [dl-checks-dev](runs/2026-10-22T22-54-06-912Z-dl-checks-dev/result.json) — 98/114, complete-with-failures

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
- (states-375x812) proxy incidents during the run: 0
- (dl-checks) 320×640 contact (merchant blocks): targets under 48px: []
- (dl-checks) 320×640 contact: merchant blocks overflow to 377px; body overflow-x clip
- (dl-checks) 390×844 contact (merchant blocks): targets under 48px: []
- (dl-checks) 390×844 contact: merchant blocks fit; body overflow-x clip
- (dl-checks) 768×1024 contact (merchant blocks): targets under 48px: []
- (dl-checks) 768×1024 contact: merchant blocks overflow to 784px; body overflow-x clip
- (dl-checks) 1024×768 contact (merchant blocks): targets under 48px: []
- (dl-checks) 1024×768 contact: merchant blocks fit; body overflow-x clip
- (dl-checks) 1440×900 contact (merchant blocks): targets under 48px: []
- (dl-checks) 1440×900 contact: merchant blocks fit; body overflow-x clip
- (negative-control-dl-blanket-serif) 390×844 contact (merchant blocks): targets under 48px: []
- (negative-control-dl-blanket-serif) 390×844 contact: merchant blocks fit; body overflow-x clip
- (negative-control-dl-single-gallery) 1440×900 contact (merchant blocks): targets under 48px: []
- (negative-control-dl-single-gallery) 1440×900 contact: merchant blocks fit; body overflow-x clip
- (negative-control-dl-discount-overflow) 320×640 contact (merchant blocks): targets under 48px: []
- (negative-control-dl-discount-overflow) 320×640 contact: merchant blocks overflow to 377px; body overflow-x clip
- (negative-control-dl-fav-40) 390×844 contact (merchant blocks): targets under 48px: []
- (negative-control-dl-fav-40) 390×844 contact: merchant blocks fit; body overflow-x clip
- (keyboard) 812×375 product: a. "PÁGINA DE PREGUNTAS FRECUENTES" is an inline link that wraps over several lines (merchant content): its ring has no box to sample; visible focus and hit test only
- (regressions-1440x900) P1 page: reloj-coach-talia-saddle; initial variant 68551021592610 "Rosa Blush", B 68551021625378 "Café", C 68551021658146 "Negro/Plateado"
- (regressions-1440x900) proxy incidents during the run: 0
