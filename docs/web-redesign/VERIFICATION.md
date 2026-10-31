# Monetta web prototype — verification record

What was actually run against `design-prototype/`, with results, coverage, the
defects found and fixed, and what was **not** verified. Three runs are recorded:
iteration 1 (2026-10-17 22:29 CST), iteration 2 after the mobile fidelity corrections
(2026-10-18 16:06 CST) and, after the independent audit, **iteration 3 (2026-10-18
18:48–19:09 CST)**, which supersedes the counts below (112 → 153 → **204** browser
checks, 25 → 31 → **49** unit tests). The sections up to “Defects found during
rendering and fixed” describe iteration 1 unless they say otherwise; iterations 3 and 2
have their own sections right after the environment (newest first).

## Environment

| Item | Value |
| --- | --- |
| Machine | macOS (Darwin 25.6.0), Claude Code Bash sandbox |
| Node / npm | v24.21.0 / 11.19.0 |
| Build tool | Vite 6.4.3 (same major as the repo's `web/`) |
| Browser for checks | Brave Browser 1.97 = Chromium 155.0.8059.40, already installed, headless, driven by `playwright-core` 1.63.0 (no browser download). Chrome is not installed and was not installed. |
| Accessibility engine | axe-core 4.13.0, tags `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa, best-practice` |
| Sandbox notes | npm's default cache is not writable here, so commands ran with `npm_config_cache="$TMPDIR/npm-cache"`. Disk had ~0.2–0.3 GB free in iteration 1 (~1.1 GB in iteration 2); captures are JPEG. Node's `fetch` refuses some ports (4045, 4190, …): a first iteration-2 attempt on 4190 failed for that reason alone, not because of the prototype. |

## Iteration 3 — corrections of the independent audit (2026-10-18)

Run from `design-prototype/` with Node 24.21.0, Brave/Chromium 155.0.8059.40, `playwright-core` 1.63.0 and
axe-core 4.13.0. The audit ([`audit-gpt-2026-10-18/`](audit-gpt-2026-10-18/AUDITORIA_GPT.md)) found that 153/153
browser checks can coexist with six open problems: those checks measured the prototype against its own values and
never tabbed to the footer, pressed Forward right after the arrow, ran axe on the search error, grew a bar to two
lines, shrank the viewport to 200 px or gave the page a side inset. The new checks do each of those with a real
browser. Per-finding tables, totals and the file map: [`correcciones-auditoria-gpt-2026-10-18/RESULTADO.md`](correcciones-auditoria-gpt-2026-10-18/RESULTADO.md);
every command's log is in [`correcciones-auditoria-gpt-2026-10-18/logs/`](correcciones-auditoria-gpt-2026-10-18/logs/).

### Commands and results (final gate)

| Command | Result |
| --- | --- |
| `npm test` | **49/49 passed** (31 earlier + 6 in `tests/unit/navigation.test.mjs` for `leaveScreen`, the arrow's fallback + 12 in `tests/unit/chrome.test.mjs` for the pinned-chrome reserve and the focus scrolling of horizontal scrollers). |
| `npm run build` | Built: `index.html` 1.99 kB, CSS 68.12 kB (12.75 kB gzip), JS 274.30 kB (61.87 kB gzip). |
| `npm run verify -- --out=../docs/web-redesign/correcciones-auditoria-gpt-2026-10-18/evidence --port=4411` | **204/204 checks passed in 424 s**: D02 10/10 · D03 35/35 · D05 6/6 · D06 8/8 · D07 5/5 · D08 3/3 · D09 44/44 · **D11 92/92** (41 fidelity + 51 audit-fix) · D10 1/1. Report: [`evidence/verify-report.json`](correcciones-auditoria-gpt-2026-10-18/evidence/verify-report.json). The 153 earlier checks are unchanged (their files are byte-identical to the archived tree) and still pass. |
| `node verify/check-audit-fixes.mjs --url=http://127.0.0.1:4402` (corrected build) | **51/51 in 253 s** ([log](correcciones-auditoria-gpt-2026-10-18/logs/check-audit-fixes-corregido.log)). |
| `node verify/check-audit-fixes.mjs --url=http://127.0.0.1:4401` (the previous tree, rebuilt from its archive) | **10/51 in 252 s**: the 41 failures are the audit's defects ([log](correcciones-auditoria-gpt-2026-10-18/logs/check-audit-fixes-base.log)). |
| `comparar-pixeles.mjs` | 384 captures, 378 identical; the 6 others differ by 1/255 in ≤ 4 pixels and the previous build differs the same way against itself (below). |
| `npm run capture -- --out=…/capturas-estandar` | 58 captures; 0 problems. |
| `npm run capture:fidelity -- --out=…/capturas-fidelidad` | 26 captures + `metrics.json` + `comparacion.html`. |
| `revision-visual.mjs` | 106 captures + 15 contact sheets; 0 console, page or network problems and 0 px of horizontal overflow. |

Both capture commands were run with an explicit `--out`: their defaults point at the October 17 and iteration 2
sets, and `npm run capture` deletes the `.jpg` files of its output folder. A clean `npm ci` was not repeated
(dependencies unchanged).

### New D11 checks (`verify/check-audit-fixes.mjs`, 51)

Real browser; shared probes in `verify/probes.mjs` (stacking from `elementFromPoint`, pixels read from screenshots,
exposed headings, axe, pinned-bar geometry, CDP safe-area emulation). The file also runs alone against any URL.

| Finding | Checks |
| --- | --- |
| GPT-01 (12) | `scroll-padding-bottom` = the real height of the dock, purchase bar and checkout bar + 16 px (collection 90, product, bag); +34 px with an emulated home indicator and back; Tab traversal from the skip link to the footer at 390×844 on collection, product, bag, Home and search (no control, text or ring hidden: hit test of the painted stacking, ring painted on 4/4 sides and ≥ 12 text pixels on every footer stop); the audit's links “Novedades”, “Envíos” and “Mi cuenta” with text, ring and separation from the dock; collection, product and bag at 375×812, 440×956 and 320×568; the bag at 768×1024 with the checkout bar still fixed. |
| A1 (2) | Tab through Home, collection and product at 390 and 320 px: every focused rail card, chip and thumbnail is fully on screen. |
| GPT-02 (8) | Forward at 0, 150, 450 and 700 ms after the arrow; a product reopened 100 ms after the arrow (same address); the arrow again after Forward; a sorted screen (arrow in one step, two Forwards restore the sorted address, the browser's Back still undoes the sort); direct link (arrow to the parent in < 400 ms, Back returns to the product); reload after a sort; entries lost by a restored session (the fallback reaches the parent after 500 ms); the browser's own Back/Forward paused 0, 700 and 1500 ms. |
| GPT-03 (3) | At 390 and 1440: exactly one exposed `h1` that names the screen and zero axe violations in empty, suggestions, results, no results and error; results → other query → back to the query keeps one `h1` each time, the heading role leaves with the suggestions and the field does not move (≤ 0.5 px). |
| GPT-04 (8) | 320×812 two-line title: reserve = measured bar edge + 16, `nearest`, real Shift+Tab onto a half-hidden card and `scrollIntoView(start)`; 375 px one-line title keeps 120 px; title at 72 px and back; resize 375 → 320 → 375; Playfair held back 1.5 s; collection → product → collection; “Ver catálogos” anchor below the header at 390 and at 1440 (strip, header and category row). |
| GPT-05 (11) | Five pages × (320×200, 360×225, 640×400 zoom equivalents; 667×375, 812×375, 844×390 on their side): ≥ 90 % of the viewport free after scrolling, no horizontal overflow; at the three zoom equivalents the product's add button, the bag's checkout (opens and closes its dialog), the filters (apply button on screen), the search (suggestions and results link) and the dock work and are not covered; Tab traversal of product and bag at 320×200; at 375×812 header, bar and dock are still pinned. |
| GPT-06 (7) | At 667×375 and 812×375 with 44 px insets: every control and visible text of eight pages inside the safe region and no overflow; the product grid between the insets (first card at 44, equal columns, row end at 623 / 768); with no inset nothing moves; menu and filters drawers, quick view sheet and bag drawer; a 34 px bottom inset below the checkout button. |

### Proof that the checks can fail

- **The previous tree, rebuilt from its archive** ([`baseline-pre-correcciones.tgz`](correcciones-auditoria-gpt-2026-10-18/baseline-pre-correcciones.tgz), 59 files hashed in the `.sha256`): 10 of 51 pass. The 10 that pass guard behaviour that had to survive: the arrow after Forward, a direct link, a reload, lost entries and paused Back/Forward; the 375 px one-line title and the 390 px anchor; header, bar and dock pinned at 375×812; no inset, nothing moves; the bottom indicator. The 41 failures carry the audit's numbers: “WhatsApp… ring covered on bottom”, “Novedades box covered by dock__item”, “after 0 ms Forward ended on /collections/carteras-1”, “suggestions: 0 exposed h1 · axe page-has-heading-one”, “scroll-padding-top vs pinned edge 125.31: 120”, “home scrolled: 29px of 200 free (site-top+dock)”, “first card left: 0 (expected 44)”.
- **Mutation of the router** ([log](correcciones-auditoria-gpt-2026-10-18/logs/gpt02-mutacion-condicion-antigua.log)): in a copy, `leaveScreen` with the old condition (`location.href === from`) fails exactly the three race tests (Forward before the timer, a link to the same address, address change or cache restore) and keeps the other three passing.
- **The first runs of the new file against the previous build** exposed harness defects, fixed so that a check fails for the audit's reason and not for a missing mechanism: reserve checks read `--pinned-*` (absent there) → they read the computed `scroll-padding`; an `auto` padding read as `NaN`; a style sheet injected with `addStyleTag` is applied a moment after it resolves; Forward steps one entry at a time.

### Pixel regression (what was not meant to change did not change)

[`comparar-pixeles.mjs`](correcciones-auditoria-gpt-2026-10-18/comparar-pixeles.mjs): 16 routes × 8 viewports (320×568, 360×800,
375×812, 390×844, 440×956, 768×1024, 1024×768, 1440×900) × 3 scroll positions on the previous build (A) and the corrected one
(B), decoded and compared in the browser with no tolerance: **378/384 identical**. The 6 others
([`comparacion-pixeles/`](correcciones-auditoria-gpt-2026-10-18/comparacion-pixeles/)) are 1 to 4 pixels each, at one gray level
(1/255), on the two empty-state pages (empty bag and 404); the control, A against A on those routes and viewports
([`comparacion-pixeles-control-base/`](correcciones-auditoria-gpt-2026-10-18/comparacion-pixeles-control-base/)), gives 7 captures that differ
by ≤ 4 pixels and ≤ 1/255 the same way. Photographs are hidden before the shot (their boxes stay): two loads of the *same* build
differ by a few levels on a bag's texture (resampling), which a first comparison with photos showed and which says nothing
about layout. Intentional changes lie outside this matrix (search error state, short viewports, insets, keyboard focus).

### Defects found and fixed in iteration 3 (in my own first version)

| Found by | Defect | Fix |
| --- | --- | --- |
| GPT-01 check (home indicator emulated after load) | The reserve stayed at 106 px while the dock grew from 90 to 124 | `ResizeObserver` reads the content box and the dock grows by padding: observe the border box |
| Visual review at 812×375 | The bag left 164 px (138 px of header + 73 px checkout bar pinned) | The short-viewport rule covers < 1024 px wide, not only phones |
| GPT-06 sweep | The skip link appeared at `left: 12px`, under the cut-out | `left: max(12px, inset)` |
| Probing the rails for GPT-01 | A focused rail card, chip or thumbnail stayed half outside the screen (“Crossbodys” 280…423 of 390; thumbnail 6 at 340…396) | `lib/scrollers.js` + `scroll-padding-inline` (A1) |
| Running the checks | The probe counted a static neighbour as covering a ring and demanded both edges of a control taller than the space the bars leave | Only fixed or sticky bars count; such a control is held to its centre |

### Visual review (D11), iteration 3

Opened as images: portrait phones 320×568, 360×800, 375×812, 390×844 and 440×956 (Inicio, colección, ficha, búsqueda, bolsa,
cuenta); phones on their side 667×375 and 812×375 with 44 px emulated insets (the six pages, menu, filters and bag drawer);
768×1024, 1024×768 and 1440×900; the 390×844 flows (filters, quick view with a required choice, a chosen variant, search
suggestions, account, menu) and the keyboard focus on “Novedades”, “Envíos” and “Mi cuenta” above the dock; 320×200, 360×225 and
640×400 at the start and end of the five pages plus the filters drawer and the checkout dialog; the standard (58) and fidelity (26)
sets. No open defect in the final captures. Contact sheets: [`revision-visual/hojas/`](correcciones-auditoria-gpt-2026-10-18/revision-visual/hojas/).

### Not verified in iteration 3

- Physical devices, Safari, Firefox and screen readers; everything ran in Chromium 155 (Brave).
- The 44 px side insets and the 21/34 px bottom insets are Chromium's `Emulation.setSafeAreaInsetsOverride`, not a real notch.
- 320×200, 360×225 and 640×400 are CSS-pixel equivalents of 400 % and 200 % zoom (1280×800, 1440×900), not the browser's zoom control.
- The back-forward cache case of the arrow's fallback (Playwright disables that cache): unit test only.
- Left unchanged on purpose: a double tap on the arrow leaves two screens.

## Iteration 2 — mobile fidelity (2026-10-18)

Run from `design-prototype/` with Node 24.21.0 and Brave/Chromium 155.0.8059.40.
The 2026-10-18 review ([`audit-2026-10-18/`](audit-2026-10-18/REVISION_FIDELIDAD_MOBILE.md))
showed that 112/112 browser checks can coexist with three fidelity differences:
those checks compare the prototype with its own values, not with the app. The new
checks therefore state facts read from the Flutter source and measure the rendered
prototype against them.

### Commands and results (final gate)

| Command | Result |
| --- | --- |
| `npm test` | **31/31 passed** (25 earlier + 6 in `tests/unit/navigation.test.mjs`: the history bookkeeping behind the in-page back arrow). |
| `npm run build` | Built: `index.html` 1.99 kB, CSS 66.07 kB (12.37 kB gzip), JS 271.36 kB (60.73 kB gzip). |
| `npm run verify -- --out=../docs/web-redesign/fidelity-2026-10-18/evidence` | **153/153 checks passed in 170 s**: D02 10/10 · D03 35/35 · D05 6/6 · D06 8/8 · D07 5/5 · D08 3/3 · D09 44/44 · **D11 41/41** · D10 1/1. Report: [`fidelity-2026-10-18/evidence/verify-report.json`](fidelity-2026-10-18/evidence/verify-report.json). The 112 earlier checks are unchanged and still pass. |
| `npm run capture:fidelity` | 26 captures + [`web/metrics.json`](fidelity-2026-10-18/web/metrics.json) + [`comparacion.html`](fidelity-2026-10-18/comparacion.html); 0 page, console or network problems, 0 horizontal overflow. |
| `npm run capture -- --out=../docs/web-redesign/fidelity-2026-10-18/screenshots` | 58 captures, [`index.json`](fidelity-2026-10-18/screenshots/index.json); 0 problems, 0 horizontal overflow. |

A clean `npm ci` was not repeated in iteration 2 (dependencies unchanged).

### New D11 checks (`verify/check-fidelity.mjs`, 41)

Real browser, phone widths 375, 390 and 440 unless stated.

| Finding | Checks |
| --- | --- |
| H01 collection (×3 widths) | Global header, breadcrumbs and toolbar hidden; one bar with exactly Volver · Buscar productos · Filtrar y ordenar, each ≥ 44×44 px; title Playfair 28/400 and a “N piezas” count. Only the bar and the shortcut row sit above the first product (budget = bar + shortcuts + 12 px, measured), the first card starts at the screen edge, two columns share the viewport with a 12 px gap, and cards of a row are equally tall. The bar stays at the strip's bottom edge after scrolling 900 px and draws its rule. Focus lands below the pinned bar (`scroll-padding-top` ≥ strip + bar, product aligned under it). |
| H01 search (×3) | “Buscar” bar with Volver and Filtrar y ordenar, plain-text title (the single `h1` is the Inter ≥ 20/600 results heading), bar → field → heading → products in order, ≤ 29 px between the heading and the first product; suggestions hide the results and the bar's filters; the empty search has `h1` “Buscar” and no filters. |
| H01 bag (×3) | Only Volver in the bar, ruled before any scrolling; title and count share the row, the count ends at the 20 px margin, the first line starts ≤ 28 px under the bar; removing a line updates the count (“3 artículos” → “2 artículos”). |
| H01 history (390) | Home → Catálogo → filter from the bar: the badge shows 1 and the label says “1 activo”; focus returns to the filters button; the browser Back removes the filter and Forward restores it; the bar arrow returns to Home; a deep link to a collection goes to Home and a style collection to Bolsas. |
| H01 wide (768, 1024, 1440) | Collection, search and bag keep the global header and category navigation, show breadcrumbs, a Playfair title ≥ 36 px, no phone back arrow or actions, nothing pinned, and the toolbar's filters button below 1200. |
| H02 header (×3) | The header's visible controls are exactly Volver · Buscar productos · Monetta · Cuenta · Carrito, in that left-to-right order; icon targets ≥ 44 px; the logo is centred within 1 px; links go to `/search` and `/account`; 4 px edge insets; the menu is not visible. |
| H02 links (390) | Search opens `/search` with the field focused; account opens `/account`. |
| H02 wide (768, 1440) | The phone-only search link is hidden; account, favourites, the header search field and (below 1024) the menu remain. |
| H03 headings (×3) | `#product-more`, `#product-recent` and `#product-reviews` compute to Inter 17px/600, and the renderer (`CSS.getPlatformFontsForNode`) reports an Inter web font. |
| H03 rails (×3) | Tiles are `min(52vw, 260)` wide (±1.5 px), photo ratio 0.8 (±0.01), photo margin 0 on a white ground, `-webkit-line-clamp: 2` with at most two lines and at least one name that wraps, and all tiles of a rail equally tall. |
| H03 Home (×3) | `#home-novedades` is still Playfair 24/400 and the first Novedades tile is the compact one (36vw clamp, square, one-line name). |
| H03 wide (768, 1024, 1440) | Headings Inter 600 at 20/22/22 px, photo ratio 0.8, equal heights, four tiles across at 1024 and five at 1440. |

### Proof that the checks can fail

Copies of the sources were deliberately reverted, the checks run, and the sources
restored (checksums compared before and after):

- Header shown on phone bar pages + toolbar row back + menu in the product header +
  Playfair headings and compact rail tiles: **22 of 39 checks failed** (for example
  “first product starts 287.8 px below the strip; bar + shortcuts + gap is 140.8 px”,
  “Abrir menú” among the product-header controls, `#product-more` computed to
  Playfair 24/400, “photo ratio: 1”).
- `scroll-padding-top: 0`: the three focus checks failed (“scroll-padding-top 0px does
  not reserve the strip and bar (104px)”). A first version of that check passed even
  with the padding removed (`focus()` centres the element), so it was rewritten to use
  the “nearest” alignment that Tab uses and to assert the reserved padding.
- The bag bar's permanent rule removed: the three bag checks failed (“the bag bar has no
  rule before scrolling: rgba(0, 0, 0, 0)”).
- Equal-height cells removed: the rail checks failed (“tiles are not equally tall: 347,
  347, 347, 347, 367, 367, 367, 367”, and a 20.3 px difference at 768).

### Defects found and fixed in iteration 2

| Found in | Defect | Fix |
| --- | --- | --- |
| Collection at 768/1440 | The new bar's 28 px title rule applied at every width, shrinking the tablet and desktop title from 36/40 px | The rule is limited to phones |
| Product → search | An empty search never kept the focus it placed on its field: the router moved focus to the heading afterwards (present since iteration 1) | Pages that place focus keep it (`meta.ownsFocus`, honoured only if focus really moved into the page) |
| Recommendation rails | Tiles of one rail differed in height (347 vs 367 px at 375) because only the grid row stretched | Each cell is a flex container and the card fills it |
| Verification harness | Port 4190 is on `fetch`'s blocked-port list: `vite preview` started but the readiness probe failed | Used ordinary ports; documented in the README |
| Verification harness | `--skip-build` after a reverted-source experiment would have tested the previous build | The final gate ran `npm run build` immediately before `npm run verify -- --skip-build` |

### Visual review (D11), iteration 2

Captures were opened as images and compared with the app captures and the
pre-correction captures:

- **375×812 and 440×956:** Inicio, colección, ficha (header), recomendaciones (“Más
  de” and “Vistas hace un momento”), búsqueda and bolsa; also the pinned collection
  bar, a brand page with an active filter (badge and removable chips), “Tommy
  Hilfiger” on one line at 375 and two at 320, the empty and no-results search, the
  filters drawer opened from the bar, the empty-filtered collection and the empty bag.
- **768 and 1440:** Inicio, colección, ficha, búsqueda, bolsa and the recommendation
  rails; the collection and search pages match the October 17 layout.
- The correction pass found the title-size, focus and rail-height defects above; the
  confirmation pass on the final captures found none open. Differences that remain are intentional and listed in
  `DESIGN_SPEC.md` §9.

Evidence: [`fidelity-2026-10-18/comparacion.html`](fidelity-2026-10-18/comparacion.html)
(app · before · after at 375 and 440), [`web/`](fidelity-2026-10-18/web/),
[`screenshots/`](fidelity-2026-10-18/screenshots/). New standard captures:
`collection__phone-390__scrolled` and `product__phone-390__recommendations`.

## Commands and results (iteration 1 final gate)

Run from `design-prototype/`:

| Command | Result |
| --- | --- |
| `rm -rf node_modules dist verify/output && npm ci` | Installed 16 packages from `package-lock.json`. npm noted that esbuild's install script is not in `allowScripts`; the build is unaffected. |
| `npm test` | **25/25 passed** (`tests/unit/commerce`, `discovery`, `fixtures`). |
| `npm run build` | Built: `index.html` 1.99 kB, CSS 61.97 kB (11.76 kB gzip), JS 268.67 kB (59.84 kB gzip, includes the 86-product catalog). |
| `npm run verify -- --out=../docs/web-redesign/evidence` | **112/112 checks passed in 138 s**: D02 10/10 · D03 35/35 · D05 6/6 · D06 8/8 · D07 5/5 · D08 3/3 · D09 44/44 · D10 1/1. Report: [`evidence/verify-report.json`](evidence/verify-report.json). |
| `npm run capture -- --skip-build` | **56 captures** written to [`screenshots/`](screenshots/), index in [`screenshots/index.json`](screenshots/index.json); no page errors during capture. |

`npm run dev` (Vite at http://127.0.0.1:5173) was used throughout development;
`npm run verify` itself exercises `vite build` and `vite preview` (port 4173).

## D02 — identity (computed and rendered)

- `document.fonts`: Inter 400, 500, 600, 700 and Playfair Display 400 all `loaded`.
- Chromium `CSS.getPlatformFontsForNode` (the font the renderer actually used):
  section heading → “Playfair Display (web font)”; card brand → “Inter SemiBold
  (web font)”; card name and price → “Inter (web font)”; category navigation →
  “Inter Medium (web font)”; primary button → “Inter SemiBold (web font)”. No
  fallback faces were used.
- Computed tokens: canvas `rgb(255,255,255)`, ink `rgb(17,17,17)`, eyebrow gold text
  `rgb(143,104,56)`, primary button `rgb(17,17,17)`, button radius 10 px, card
  radius 12 px, inset media radius 8 px, product photos `object-fit: contain`, hero
  `cover`, section heading weight 400, card price weight 700, search field pill.
- Wordmark: the app's `logo-monetta.png` (132×38 source, 2×/3× via `srcset`)
  rendered 111×32 on desktop — ratio preserved.
- Phone dock: selected item `rgb(197,160,82)` (boutique gold) with
  `rgb(23,23,21)` text.
- Visual: identity reviewed in the captures for all pages (wordmark, Playfair
  headings, Inter controls, white ground, grey bars, gold accents, 12 px cards).

## D03 — responsive coverage

Each cell: page loaded, scrolled through (lazy images and reveals), then checked
for `scrollWidth ≤ clientWidth`, no element escaping the viewport outside a
scroller, no broken image, the expected fixed bottom control and footer
clearance ≥ 0.

| Page | 375 | 390 | 440 | 768 | 1024 | 1280 | 1440 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Home `/` | ✓ dock | ✓ dock | ✓ dock | ✓ — | ✓ — | ✓ — | ✓ — |
| Collection `/collections/guess` | ✓ dock | ✓ dock | ✓ dock | ✓ — | ✓ — | ✓ — | ✓ — |
| Product `/products/bolso-coach-shoulder-negro-rectangular` | ✓ purchase dock | ✓ purchase dock | ✓ purchase dock | ✓ — | ✓ — | ✓ — | ✓ — |
| Search `/search?q=bolsa&type=product` | ✓ dock | ✓ dock | ✓ dock | ✓ — | ✓ — | ✓ — | ✓ — |
| Cart `/cart` (2 seeded lines) | ✓ checkout bar | ✓ checkout bar | ✓ checkout bar | ✓ checkout bar | ✓ — | ✓ — | ✓ — |

All 35 cells: horizontal scroll width equal to the viewport. Reflow at 320 px
(400% zoom of a 1280 px window): all five pages 320/320.

Captures for every principal page at phone (390), tablet (768) and desktop
(1440), plus intermediate checks at 375 (product, cart), 1024 and 1280
(collection), are listed below. Defects found at intermediate widths (header
overlap at 1024, tablet hero type) were fixed and re-captured.

## Interaction scenarios (D05–D08)

| Gate | Scenario (real browser) | Result |
| --- | --- | --- |
| D06 | Typing “coach” in the header search shows suggestions and products; ArrowDown sets `aria-activedescendant`; Escape closes | 8 options |
| D06 | Enter carries the query to `/search?q=coach&type=product` | “Resultados para “coach”” · 16 piezas |
| D06 | Sidebar “Relojes” + sort “Precio: menor a mayor” update URL, count and chips | 16 → 4 piezas; prices 3647, 3789, 5259.15, 6836.99 ascending |
| D06 | Back restores the previous sort, then the unfiltered results | both states restored, checkbox and count included |
| D06 | Impossible filter → “Sin resultados” → “Limpiar filtros” | 8 watches return |
| D06 | Load more → `page=2`, open a product, Back | 48 cards kept, scroll 4479 → 4479 |
| D06 | Suggestion failure (demo switch) | error + Reintentar; Enter still opens results |
| D06 | Phone filter drawer: draft count, apply, Back | “Ver 10 piezas” → URL filter + chip → Back removes it |
| D05 | Card states | genuine −10% with $1,899.00 compare-at; sold-out seal without “+”; “Sobre pedido” eyebrow |
| D05 | Long name | 73 characters intact in the DOM, 2 visible lines |
| D05 | Guest favourites | saved from a card, listed with the device-only notice, removed to the empty state |
| D05 | Quick view on a multi-variant product | starts disabled (“Elige una opción”); choosing Café puts `?variant=47886205386903` on “Ver detalles completos”; product page opens with Café selected |
| D05 | Sobre pedido / apartado / sold out | availability line; apartado dialog says nothing is reserved or charged; sold-out button “Agotado”, `aria-disabled` |
| D05 | Blocked storage (demo switch) | favourites page explains they last only for the visit |
| D07 | Two rapid clicks on “Agregar al carrito” | “Agregando…” shown, quantity 1, header count 1, live region “Agregado al carrito: Bolso Coach Shoulder Rectangular (Color: Café).” |
| D07 | Drawer + / Eliminar / Deshacer, Escape | 1 → 2, removed, undone, focus back on the add button |
| D07 | Checkout | handoff dialog lists the exact variant ID and states no order, reservation or payment |
| D07 | Empty the cart | “Tu bolsa está vacía” → “Volver a la tienda” → Novedades |
| D07 | Failed add (demo switch) | “No pudimos agregar la pieza. Intenta de nuevo.” beside the button; cart unchanged; retry succeeds |
| D08 | Phone home | dock visible; header search icon appears only after the hero search scrolls away |
| D08 | Phone search typing | dock slides away while the field has focus |
| D08 | Phone product → add → cart | purchase dock replaces the nav dock; the sheet makes the page inert; cart shows only the checkout bar |

No live cart, checkout, account or Shopify endpoint is contacted; every external
action is a dialog. No forms are submitted and no messages are sent.

## Accessibility (D09)

- **axe:** 33 states scanned with zero findings of any impact (critical, serious,
  moderate or minor): the five principal pages at 390 and 1440; brand,
  favourites, Mayoreo, story, contact, account, policy and not-found pages at both
  widths; menu drawer, filter drawer and quick view (390); cart drawer, open
  predictive search, checkout handoff and prototype panel (1440).
- **Keyboard:** skip link is the first stop and moves focus into `main`; 14
  consecutive tab stops on home all show a visible focus indicator; variant radios
  change with arrow keys (URL updates); menu drawer and quick view keep focus for
  25–30 Tabs and Escape returns focus to the trigger.
- **Reduced motion:** with `prefers-reduced-motion: reduce`, editorial sections are
  visible immediately (opacity 1) and transitions are effectively disabled.
- **Reflow/zoom:** 320 px reflow passes on all principal pages.
- **Contrast (computed):** ink 18.88:1; muted ink 5.68:1 on white, 4.99:1 on
  `#F0F0F0`; gold text 4.99:1; white on sale red 6.81:1; dark text on gold 7.29:1.
  Gold `#C5A052` is only used for marks and fills, never small text on white.
- **Announcements:** add-to-cart, removals, filter counts, search results and
  errors use the polite/assertive live regions.
- **Manual review** of the captures: headings in order, labels visible, focus
  rings clear, no information carried by colour alone (sold-out text + strike +
  seal; selection fill + border + check).

## Console and network (D10)

Across all verification visits: **no console errors, page errors, failed
requests or HTTP ≥ 400 responses**. All assets are local; fonts, images and data
load from the prototype server.

## Defects found during rendering and fixed

| Found in | Defect | Fix |
| --- | --- | --- |
| Home 390 | Page scrolled sideways (473 px) | A visually hidden label inside a horizontal rail escaped the scroller; rails are now `position: relative` |
| All rails | Side padding ignored | A base `ul[role=list]` rule outranked component padding; now `:where()` (zero specificity) |
| Product | “AGOTADO” seal over an available variant | `display: grid` overrode `[hidden]`; global `[hidden] { display: none !important }` |
| Product 390 | Info panel had no side gutter | Panel padding added below 768 |
| Product | Generated description named one colour for an 8-colour product | Multi-variant products say “disponible en N opciones”; Detalles lists the options |
| Product 390 | Reviews rail widened the page (1047 px) | Grid track `minmax(0, 1fr)` and `min-width: 0` on rails |
| Collection 390 | Style chips overlapped | Scrolling chip items no longer shrink |
| Header 1440 | Account/favourites labels underlined; labels stacked under icons | Utilities are inline-flex without underline |
| Header 1024 | Search field ran under “Cuenta” | Desktop grid gives utilities their content width |
| Predictive search | Panel spanned the whole page below the nav | Panel anchored to the field (`.header-search { position: relative }`), 640 px |
| Cards, gallery | `aria-pressed`, `aria-current`, slide indicator rendered empty until a later update; saved hearts looked black | Booleans stringified; `html()` now throws on a bare `true` so this cannot recur silently |
| Brand page | `aria-pressed` on links | `aria-current="true"` |
| axe | Scrollable review rails and search popup not keyboard-reachable; strip outside landmarks; duplicate search landmarks | Review rails focusable; popup footer links outside the listbox; strip is an `aside`; unique search labels |
| Phone cart | “Continuar al checkout” wrapped in the bar | Bar label “Ir al checkout” |
| Tablet | Hero heading in four lines; cut nav labels | 28 px tablet tagline; fade edge on the scrolling row; two-up reviews |
| Desktop gallery | Viewer extended below the fold at 900 px | Height budget includes the breadcrumb row |
| Capture only | Full-page screenshots showed slide 1 in the gallery while the variant's thumbnail was active | Chromium's full-page capture resets horizontal scrollers; `capture.mjs` pins the visible slide before full-page shots. Normal resizes keep the right slide (checked: index 2 before and after a resize at 390/768/1440). |

## Screenshots

**Current set (iteration 2):** [`fidelity-2026-10-18/screenshots/`](fidelity-2026-10-18/screenshots/)
— 58 captures with the same naming plus `collection__phone-390__scrolled` and
`product__phone-390__recommendations`; the side-by-side pairs are in
[`fidelity-2026-10-18/web/`](fidelity-2026-10-18/web/). The list below describes the
October 17 set in [`screenshots/`](screenshots/), kept as history: its phone
collection, search, bag and product views predate the fidelity corrections.

[`screenshots/`](screenshots/) — named `{page}__{device}-{width}__{state}.jpg`.
Phone viewport shots are 2× density; full-page shots are 1×. In full-page captures
the phone dock is drawn at its first-viewport position (a property of full-page
capture, not the layout).

- **Home:** `home__phone-390__top`, `home__phone-390__full`, `home__tablet-768__full`, `home__desktop-1440__top`, `home__desktop-1440__full`
- **Collection/brand:** `collection__phone-390__top`, `__full`, `collection__tablet-768__full`, `collection__laptop-1024__top`, `collection__wide-1280__top`, `collection__desktop-1440__full`, `collection__desktop-1440__filtered`, `collection__phone-390__filter-drawer`, `collection__phone-390__empty-filtered`, `brand__desktop-1440__coach`
- **Product:** `product__phone-390__top`, `__options`, `product__phone-375__purchase`, `product__phone-390__full`, `product__tablet-768__full`, `product__desktop-1440__top`, `__full`, `__sale`, `__envio-inmediato`, `product__phone-390__sold-out`, `product__desktop-1440__quick-view`, `__apartado`, `product__phone-390__added-sheet`, `product__desktop-1440__add-error`
- **Search:** `search__phone-390__suggestions`, `__predictive`, `__results`, `search__tablet-768__full`, `search__desktop-1440__predictive`, `__results`, `__no-results`, `__suggestion-error`, `__results-error`
- **Cart:** `cart__phone-390__top`, `cart__phone-375__summary`, `cart__tablet-768__full`, `cart__desktop-1440__full`, `__drawer`, `__checkout-handoff`, `cart__phone-390__empty`
- **Supporting:** `menu__phone-390__open`, `favorites__desktop-1440__items`, `favorites__phone-390__empty`, `mayoreo__phone-390__top`, `mayoreo__desktop-1440__full`, `story__desktop-1440__full`, `contact__phone-390__full`, `account__desktop-1440__entry`, `account__desktop-1440__handoff`, `prototype-panel__desktop-1440`, `not-found__tablet-768`

## Visual review (D11), iteration 1

D11 was reopened on 2026-10-18 and closed again after the review in
“Iteration 2” above; this section is the October 17 record.

1. **Correction pass** (captures of all pages and overlays at 390, 768, 1024,
   1280, 1440): defects listed above were fixed.
2. **Confirmation pass** on the final captures of home, collection, product,
   search and cart at phone, tablet and desktop, reviewed together: type roles,
   crops, card density, navigation, purchase hierarchy, overlays and focus are
   consistent with the app and with `DESIGN_SPEC.md`. No open defect breaks the
   brand, layout, accessibility or shopping interactions.

## Not verified

- **Real devices and other engines:** iOS Safari, Android Chrome, Firefox and
  desktop Safari were not available; all checks ran in Chromium 155 (Brave). Safe
  area insets, real software keyboards and mobile browser toolbars were not
  observed; the CSS uses `env(safe-area-inset-bottom)` and
  `interactive-widget=resizes-content`, and the dock hides while typing.
- **Screen readers:** no VoiceOver/TalkBack/NVDA session; semantics were checked by
  axe and by inspecting roles, names and live regions.
- **Shopify behaviour:** cart API errors, automatic wholesale discounts,
  predictive search responses, facets, Loox and Labeler output, checkout and
  account branding are simulated or described, not exercised. See
  `IMPLEMENTATION_HANDOFF.md` §11.
- **Performance:** no Lighthouse, field data or LCP/INP/CLS measurement. The
  prototype bundles its catalog and is not a performance reference.
- **Live data freshness:** prices, stock and descriptions are the 2026-10-17
  snapshot.
- **Pixel comparison with the app:** none. The app references are the Flutter widget
  renders of the 2026-10-18 audit (products from another snapshot, photos as
  placeholders), compared by eye and by measured values, not by an automatic diff
  between engines; no run on a physical device.
- **Multi-page behaviour of the back arrow:** the screen-level arrow relies on this
  prototype's single-page router; how a Shopify theme should do it is specified in
  `IMPLEMENTATION_HANDOFF.md` §4, not exercised.
- **Other phone interior views** (favourites, account, Mayoreo, story, contact,
  policies, 404) still use the global phone header and were not part of H01–H03.
- **Iteration 3 (audit corrections):** real devices, Safari and Firefox, screen readers, the browser's own zoom control, a real
  notch and the back-forward cache case of the arrow were not exercised — see “Not verified in iteration 3” above.
