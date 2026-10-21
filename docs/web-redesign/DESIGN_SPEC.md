# Monetta web — design specification

The responsive web design for monetta.mx, as built in the prototype
(`design-prototype/`). It carries the current app's boutique layer to phone,
tablet and desktop. Values are exact: they are the ones the prototype renders and
the verification suite checks.

**Source priority.** Current app rendering code and bundled assets
(`lib/features/boutique/boutique_tokens.dart`, the home, card, dock and product
widgets, `lib/app/motion.dart`, `assets/`) ▸ app goldens interpreted against that
code ▸ `docs/MONETTA_WEB_REDESIGN_PLAN.md` ▸ older reference boards. Where the web
departs from the app, §9 gives the reason.

Visual references (current, after the audit corrections of iteration 3):
[`correcciones-auditoria-gpt-2026-10-18/capturas-estandar/`](correcciones-auditoria-gpt-2026-10-18/capturas-estandar/)
(58 browser captures, indexed in [`index.json`](correcciones-auditoria-gpt-2026-10-18/capturas-estandar/index.json)),
the side-by-side set [`capturas-fidelidad/`](correcciones-auditoria-gpt-2026-10-18/capturas-fidelidad/) (375 and 440 px
plus tablet and desktop, with [`comparacion.html`](correcciones-auditoria-gpt-2026-10-18/capturas-fidelidad/comparacion.html))
and the 106 review captures with contact sheets in
[`revision-visual/`](correcciones-auditoria-gpt-2026-10-18/revision-visual/) (320 → 1440, phones on their side with
emulated side insets, short viewports). The iteration 2 sets
[`fidelity-2026-10-18/screenshots/`](fidelity-2026-10-18/screenshots/) and
[`fidelity-2026-10-18/web/`](fidelity-2026-10-18/web/) are kept as history, as is the October 17 set in
[`screenshots/`](screenshots/) (stale for the phone collection, search, bag and product views).

---

## 1. Identity

- **Wordmark.** The app artwork (`logo_monetta.png`, 1×/2×/3× = 132×38, 264×76,
  396×113, ratio ≈ 3.47:1) at 24 px tall on phones and tablets, 32 px on desktop,
  21 px in the menu drawer, 26 px in the footer. Never redrawn with a font, never
  recoloured; `srcset` picks the density.
- **Favicon.** `monetta_favicon.png` (32 and 96 px).
- **Photography.** Product packshots stay whole (contain). Editorial photos use
  deliberate cover crops with recorded focal points (§6). No stock imagery, no
  text baked into images, no decorative gradients beyond the collection-card
  legibility scrim the app already uses.
- **Voice.** Spanish (es-MX), short and calm: “Agregar al carrito”, “Mi bolsa”,
  “Sobre pedido”, “Se calcula en el checkout”. No urgency or scarcity copy.

## 2. Colour tokens

| Token | Value | Use | Contrast |
| --- | --- | --- | --- |
| `--color-canvas` | `#FFFFFF` | Page, cards, header, drawers | — |
| `--color-surface` | `#FAFAFA` | Photo mats, summary panels, quiet panels | — |
| `--color-surface-deep` | `#F0F0F0` | Search field, chips, selected option fill, skeletons | — |
| `--color-bar` | `#F5F5F5` | Purchase dock, checkout bar, prototype strip, footer | — |
| `--color-ink` | `#111111` | Text, primary buttons, focus ring | 18.88:1 on white |
| `--color-ink-muted` | `#6B6660` | Secondary text, card names, inactive dock items | 5.68 white · 5.21 bar · 4.99 surface-deep |
| `--color-gold` | `#C5A052` | Selected dock fill, count badges, timeline marks, stars, nav underline — never small text on white (2.46:1) | ink on gold 7.29:1 |
| `--color-gold-text` | `#8F6838` | Eyebrows, “Sobre pedido”, saved hearts | 4.99 white · 4.58 bar |
| `--color-sale` | `#A3342B` | Genuine discount badge (white text), error text | 6.81:1 both ways |
| `--color-hairline` | `rgba(17,17,17,.12)` | Card borders, dividers | — |
| `--color-hairline-strong` | `rgba(17,17,17,.28)` | Inputs, option chips, steppers | — |
| `--color-on-dark` | `#F8F5EE` | Titles on collection photographs (over the scrim) | — |
| `--color-scrim` | `rgba(17,17,17,.45)` | Overlay backdrop | — |
| `--color-dock-ink` | `#171715` | Text/icon on the gold dock pill and badges | 7.29:1 on gold |

Light appearance only for launch. The older shared accent `#AA7D44` is not used.

## 3. Typography

Inter (400, 500, 600, 700) and Playfair Display (400) from the app's bundled
OFL fonts, served as WOFF2 with `font-display: swap`; Regular, SemiBold and
Playfair are preloaded. Fallbacks: Georgia for the serif, `system-ui` for the sans.

| Role | Family / weight | Phone | Tablet | Desktop | Line height · tracking |
| --- | --- | --- | --- | --- | --- |
| Section heading (`.display--section`), Home's editorial sections | Playfair 400 | 24 | 30 | 34 | 1.12 · −0.012em |
| Product section heading (`.product-section-title`): Reseñas, Más de {marca}, Vistas hace un momento | Inter 600 | 17 | 20 | 22 | 1.25 · −0.006em |
| Page title (`.display--page`) | Playfair 400 | 30 | 36 | 40 | 1.12 · −0.012em |
| Page-bar title (collections, search, bag; `.page-bar__title`) | Playfair 400 | 28 | 36 (page title) | 40 (page title) | 1.12 · −0.012em |
| Search results heading (phone) | Inter 600 | 20 | page title | page title | 1.25 · −0.006em |
| Page-bar count / bag count (phone) | Inter 400, muted | 13 / 12 | 14 | 14 | 1.2 |
| Hero tagline (`.display--hero`, tablet/desktop only) | Playfair 400 | — | 28 | 42 | 1.1 |
| Dialog/drawer title | Playfair 400 | 22 | 22 | 22 | 1.2 |
| Collection-card title | Playfair 400 | 24 | 24 | 30 | 1.12 |
| Product name (`h1`) | Inter 600 | 24 | 26 | 30 | 1.25 · −0.006em |
| Product price | Inter 700 | 20 | 22 | 24 | 1.2, with “MXN” |
| Card brand | Inter 600 | 13 (compact 12) | | | 1.25 |
| Card name | Inter 400, muted | 14 (compact 13), 2 lines (compact 1) | | | 1.3 |
| Card price | Inter 700 | 16 (compact 14) | | | 1.2 |
| Compare-at price | Inter 400, muted, struck | 13 (compact 11) | | | |
| Body / reading copy | Inter 400 | 16 | 16 | 16 | 1.6 |
| Controls, buttons | Inter 600 | 15 (small 14) | | | 1.15 |
| Category navigation | Inter 500 | — | 14 | 14 | |
| Eyebrow / metadata | Inter 500, uppercase | 11 | 11 | 11 | 1.3 · 0.127em |
| Dock labels | Inter 400 | 11 | — | — | 1.25 |
| Menu drawer links | Playfair 400 | 20 | 20 | — | 1.2 |

Inputs use 16 px so mobile Safari never zooms on focus.

## 4. Geometry, spacing, elevation, motion

| Token | Value | Notes |
| --- | --- | --- |
| `--radius-card` | 12 px | Cards, panels, galleries, dialogs |
| `--radius-control` | 10 px | Buttons, inputs, steppers, option chips |
| `--radius-tile` | 8 px | Inset product photo, thumbnails |
| `--radius-pill` | 999 px | Search field, chips, badges, dock items |
| `--radius-dock` | 40 px | Floating dock bar |
| Menu drawer | 0 30 30 0 | As the app drawer |
| Sheet | 16 px top corners | Phone sheets (quick view, “En tu bolsa”) |
| Space scale | 4, 8, 12, 16, 24, 32, 48, 64 | `BoutiqueSpace` plus 48/64 for desktop rhythm |
| `--control` / `--tap` | 52 / 48 px | Primary buttons / minimum target |
| `--shadow-card` | `0 4px 12px rgba(0,0,0,.035)` | Hover lift: `0 10px 24px rgba(0,0,0,.07)`, −2 px |
| `--shadow-float` | `0 1px 6px rgba(0,0,0,.12)` | Quick-add circle |
| `--shadow-dock` | `0 10px 30px rgba(17,17,17,.1)` | Floating dock |
| `--shadow-panel` | `0 24px 64px rgba(17,17,17,.18)` | Dialogs, predictive panel, toasts |
| Motion | 180 ms controls · 280 ms drawers/sheets · 480 ms editorial reveal | Ease `cubic-bezier(.16,1,.3,1)` (`kMotionCurve`) |

Reveals apply only to editorial sections below the first viewport (story, social,
reviews), as one group each. The hero, grids, navigation and purchase controls are
never delayed. `prefers-reduced-motion: reduce` disables transitions, animations,
smooth scrolling and reveals.

## 5. Responsive rules

| | Phone < 768 | Tablet 768–1023 | Desktop ≥ 1024 |
| --- | --- | --- | --- |
| Gutter | 20 px (16 below 360) | 32 px | 40 px; 48 px from 1280 |
| Content width | Full | Full | Max 1440 px |
| Section gap | 32 px | 48 px | 64 px |
| Header | Home and supporting pages: 60 px menu · centred wordmark · search icon. Collections, brands, search and bag: no global header — the pinned 76 px page bar (§7). Product: 60 px back + search · centred wordmark · account + bag | 64 px: menu · wordmark · search field · account / favourites / cart icons; scrolling category row with a fade edge (back arrow and menu on product pages) | 72 px: wordmark · 560 px search field · Cuenta / Favoritos / Carrito with labels; centred category row (44 px) |
| Bottom control | Floating dock on browsing pages; purchase dock on product; checkout bar on a non-empty cart. None of them is pinned below 480 px of height (short viewports, below) | Checkout bar on cart only (same exception) | None |
| Product grid | 2 columns (1 below 360). Collection, brand and search results run edge to edge with a 12 px gap (the app's grid); other grids keep the gutter | 3 columns | 3 columns; with the filter sidebar from 1200: `auto-fill, minmax(208px, 1fr)` → 4 columns from ~1250 |
| Filters | Drawer | Drawer | Drawer below 1200; 240 px sticky sidebar from 1200 |
| Home rails | Swipe; next card peeks (compact cards 36vw, 132–190 px) | 3.2 cards visible | 4 visible, previous/next buttons |
| Product recommendation rails | Swipe; tiles 52vw (≤ 260 px), 4:5 photo, two-line names; the next tile peeks | 3.2 tiles visible | 4 visible; 5 from 1200, previous/next buttons |
| Product | Full-bleed gallery, info below, purchase dock | Two columns (1.08 : 1) | Gallery 58% (thumbnail column + viewer fitted to the viewport height) · sticky panel 42% |
| Cart | Lines, summary, checkout bar | Same | Lines 7 : summary 4 (sticky) |

Height comes from content: no fixed card heights, names clamp at two lines but the
full name stays in the accessible name, prices wrap as whole units. The layout
was swept at 375, 390, 440, 768, 1024, 1280 and 1440 px and at 320 px (400% zoom
reflow) with no horizontal scrolling (see `VERIFICATION.md`).

**Fixed controls never stack.** Exactly one bottom control is visible at a time;
`--bottom-ui` reserves its height in the footer and lifts toasts above it. All
bottom bars add `env(safe-area-inset-bottom)`; the viewport uses
`viewport-fit=cover, interactive-widget=resizes-content`. While a text field has
focus on a phone, the dock slides away so the keyboard and dock never compete.
Dialogs and drawers make the page behind them inert.

**Pinned chrome is measured, not assumed.** `src/lib/chrome.js` publishes two custom
properties on `<html>`: `--pinned-top`, the lowest edge of the strip, header and page
bar that stay on screen while the page scrolls, and `--pinned-bottom`, the height of
the dock, purchase bar or checkout bar that sits over the content. `scroll-padding-top`
and `scroll-padding-bottom` are those values plus 16 px, so keyboard focus, anchors and
`scrollIntoView` stop short of the bars whatever size they really have: a page bar that
wraps its title to two lines (97.3 px instead of 76 at 320 px), a header that changes
with a late web font or larger text, a dock that adds the home indicator (90 px + the
inset, not the 88 px the layout used to assume), the tablet and desktop category row
(146 px of header at 1440, not 116). Only bars that are `sticky` or `fixed` count: a bar
that a short viewport turns into normal flow reserves nothing. The reserve is read again
on resize, orientation change, web-font load, body-class change and every route render,
and the elements are observed by their border box (the dock grows through its padding).
Until the first measurement `--pinned-top` falls back to strip + header.

**Short viewports.** Under 480 px of height, **at any width** — a phone on its side, a
laptop window at 400 % zoom (1280×800 reflows to 320×200, 1440×900 to 360×225, 200 % to
640×400), or a desktop window with its developer tools open — nothing stays pinned: the
strip, header and page bar scroll away with the page, the dock joins the end of it
(static, on the footer's grey), and the purchase bar and checkout bar give way to the
buttons the page already carries (the inline “Agregar al carrito”, the bag's summary
“Continuar al checkout”). Before, 320×200 left 14 px between header and dock on a
collection and 360×225 left 39; now the content has the whole viewport. The first
version of the rule stopped at 1023 px wide; at 1024×200 the header (146 px) and the
category row stayed pinned and left 54 px of 200, one pixel of width away from a window
that left all 200.

The desktop columns that stick under the header, and the gallery sized to fit below it,
are computed against a header that stays (strip + header + category row = 146 px), so
the same rule makes them flow with the page when the window is short: the filter
sidebar (from 1200 px), the product panel and the bag summary stop being `sticky`, and
the product gallery drops its viewport-fitted `max-width` and thumbnail `max-height`.
Left alone, those formulas collapsed at 1280×200 (gallery viewer 0×0 px, its thumbnails
7 px, the filters 23 px) or pinned a column 169 px from the top of a 200 px window. From
481 px up nothing changes: the header stays pinned, the columns stay sticky and the
gallery stays fitted (1024×481 and 1440×481 still give a 197 px viewer; the design's
fit is the design's).

**Safe region.** Landscape phones put the notch and rounded corners at the sides. The
tokens `--safe-left/right` (`env(safe-area-inset-*)`) and `--edge-l/r =
max(gutter, inset)` say where content starts at each side; every full-bleed row (rails,
chip rows, thumbnails, the page bar, the search field's band, bars) undoes exactly the
container's edge. Photographs and bar backgrounds still bleed to the screen edge; text
and controls never sit under a cut-out. The edge-to-edge product grid runs from the
inset (`margin-inline: inset − edge`, the app's `SliverSafeArea`): at 667 px with 44 px
insets the first card starts at x = 44 and the two 283.5 px columns end at 623. Drawers
keep their panel colour under the cut-out and move their content clear of it; sheets and
dialogs, the toast, the dock and the purchase/checkout bars do the same. With no inset
nothing moves (compared pixel by pixel in `VERIFICATION.md`).

## 6. Image treatment and crops

| Image | Treatment | Crop / focal point | Source size |
| --- | --- | --- | --- |
| Home hero, phone | Full-bleed, `cover`, height `clamp(220px, 30vh, 280px)` | `50% 72.5%` (app `Alignment(0, .45)`): hand, watch and bag hardware | 736×981 |
| Home hero, tablet/desktop | Photo panel (58% desktop), radius 12, height `clamp(340px, 42vw, 460px)` | `50% 64%` | same file; a dedicated landscape asset is recommended (handoff §5) |
| Product photo (cards, gallery, cart, search) | `contain` on `#FAFAFA` with `mix-blend-mode: multiply` so near-white packshot grounds disappear | Whole product | 800 px WebP, mostly 3:4 |
| Card frame | 4:5 grid, 1:1 compact; 8 px inset, radius 8 | — | |
| Recommendation tile (product page) | 4:5, no inset: the packshot fills the frame on white (the app's `photoInset: 0`) and the card's top corners clip it | Whole product | |
| Gallery | 4:5 slides, swipe/scroll-snap, thumbnails 56×68 (phone) / 72×88 (desktop column) | Variant photo first | |
| Style tiles | `contain`, transparent ground | Whole silhouette | 600×600 |
| Collection cards | `cover`, radius 12, scrim `transparent 46% → rgba(0,0,0,.72)` | Bolsas `50% 38%`, Carteras `50% 55%`, Relojes `50% 50%` | 800×815–1000 |
| Story image | Oval cut-out: `cover` in a 1 : 1.3 portrait on phones, `contain` 4:3 on wider screens | Centre | 1200×900 |
| Brand logos | Cropped to the artwork bounds of the 600 px squares (from `_brandLogoBounds`) | — | 600×600 |
| Review photos | `cover`, 4:3 | Centre | 1080–1440 |

## 7. Components and states

### Prototype strip (prototype only)
28 px band in `--color-bar` above the header: “Prototipo de diseño · datos de
muestra” (+ date and “nada se compra ni se envía” from 768) and a “Detalles” button
that opens the prototype panel. It is an `aside` landmark. **Not part of the
production theme.**

### Page bar (phones: collections, brands, search, bag)
`lib/features/navigation/monetta_page_header.dart` for the web. Below 768 px these
pages have no global header: they open with one bar, drawn inside `main`, pinned
under the prototype strip, white with a hairline once the page scrolls.
- **Anatomy.** 76 px minimum height (grows when the title wraps to two lines): a 48 px
  back button at the left edge (20 px arrow), the title in Playfair 28 with an optional
  13 px muted count line under it, and the page's actions at the right edge, 48 px
  each. The bag puts its 12 px count at the right instead of actions.
- **Collections and brands:** back · title + “N piezas” · search · filters. The
  filters icon carries the count of active filters (ink badge) and its name says how
  many are active; it opens the same drawer as before (sort included).
- **Search:** back · “Buscar” · filters when there are results. Below it, the 52 px
  field, a full-width hairline, and the results heading in Inter 600 20 with the count
  at its right. The page always has exactly one `h1`: the bar's “Buscar” when there is no
  query or the results failed to load (the bar then shows at every width, like the empty
  search), the results heading when there are results to name (“Resultados para “q””,
  with or without matches; the bar title is plain text and the bar is phone-only). While
  the suggestions replace the results the bar's title takes the heading role
  (`role="heading" aria-level="1"`): visible on phones, visually hidden from tablet up so
  the field does not move.
- **Bag:** back · “Mi bolsa” (`h1`) · “N artículos”, ruled from the start (the app's
  first line draws its top border right under the header); the other bars draw their
  rule only once the page scrolls.
- **Back arrow.** It leaves the screen: filters and sort push history entries so the
  browser's Back can restore them, and the arrow skips those entries. When the visit
  began on the screen it goes to the parent: Home, or Bolsas for a style collection.
  If the browser does not move (a restored session lost the earlier entries) the arrow
  follows the parent after 500 ms so it is never dead — a fallback that belongs to the
  click that armed it: the traversal arriving, Forward, a link, a changed address or a
  page restored from the back-forward cache cancel it, whatever address the page is at
  when the timer fires. Tapping the arrow twice quickly still leaves two screens, as
  before.
- **Pinned chrome.** `scroll-padding-top` is the measured edge of the strip and the bar
  plus 16 px (§5), so keyboard focus and anchors never land under them, however tall
  the bar has grown. Short viewports unpin the bar (§5).
- **Tablet and desktop.** The bar is only the title row (back and actions hidden):
  breadcrumbs above, title left, count right, exactly as before.

### Header and navigation
- White, hairline appears once the page scrolls. Sticky with the strip.
- Phone home: the search icon appears only after the hero search pill leaves the
  viewport (the app's handover).
- Phone product page (`product_header.dart`): back and search at the left, the
  wordmark centred, account and bag at the right — 48 px targets after a 4 px edge
  inset on each side, so the logo stays centred. The menu does not take the search
  position; the bag keeps its count badge. Account opens the prototype's `/account`
  entry (the Shopify handoff). Tablet and desktop keep menu, search field and
  utilities.
- Category row (tablet and desktop): Novedades · Bolsas · Carteras · Relojes · Marcas (dialog
  listing brand collections and brand filters) · Perfumes ↗ · Maquillaje y skincare ↗
  (external catalogs) · Vende con Monetta · Nuestra historia. Current item: 2 px gold
  underline. The row is 44 px tall and scrolls horizontally, so it clips whatever falls
  outside it and it has to be built for that:
  - *Tablet (768–1023 px):* a soft fade over the last 12 % says there is more. The row
    keeps real end padding as wide as the fade plus the ring (`12% + 8px`), because
    `scroll-padding` frames a focused link but adds no scrollable room: at 768 px the last
    link used to end inside the fade at the end of the scroll (words 630–736 px, fade from
    676); now the row scrolls 330 px instead of 249 and it ends at 667 px.
  - *Desktop (≥ 1024 px):* no fade. The row is as wide as its links (`width: fit-content`,
    capped at the window) and its own auto margin centres it: centred when the links fit and,
    when they overflow a little (1024–1059 px, or with a side inset), as wide as the window,
    starting on the gutter or the inset and scrolling. `justify-content: center` split the
    overflow between both sides: the first link sat at x = 23 at 1024 px (under the inset with
    one) and its left part could not be scrolled to. Where the links fit the positions are
    exactly the previous ones.
  - *Focus ring:* drawn **inside** the link (`outline-offset: −4px`) at every width from
    768 px; outside it the row's own clip took its top and bottom edges (two brackets left).
- Count badges: gold circle, `#171715` text, “9+” above nine.

### Menu drawer (phone, tablet)
Left drawer, white, wordmark and close; “Inicia sesión” (quiet button → account
handoff); links with light stroke icons and Playfair labels: Novedades, Bolsas,
Carteras, Relojes, Perfumes and Maquillaje y skincare (each marked “Catálogo
externo ↗”), Todas las marcas, Vende con Monetta, Favoritos; footer group
Contacto, Nuestra historia. “Ajustes” from the app is omitted (no web settings).

### Search
- **Field.** Pill, 48 px (52 on the search page), `#F0F0F0`, hairline; focus: white
  with an ink ring. Placeholder rotates through the app's prompts (“Encuentra algo
  muy tú”…). Clear button when filled.
- **Predictive panel** (header popup on tablet/desktop, inline on the search page).
  ARIA 1.2 combobox + listbox; arrow keys move the active option
  (`aria-activedescendant`), Enter opens it or submits, Escape closes.
  - *Initial:* Búsquedas recientes (with “Borrar historial de búsqueda”),
    Sugerencias (Bolsas, Carteras, Relojes, Crossbodys, Totes), 3 Novedades,
    “Ver todo el catálogo”.
  - *Typing:* after 160 ms debounce; a skeleton appears if the answer takes longer
    than 120 ms.
  - *Results:* query suggestions with counts (only terms with results), up to 5
    products (thumb, brand, name, price), “Ver los N resultados de “q””.
  - *No matches:* message + three category shortcuts.
  - *Error:* “No pudimos cargar las sugerencias” with Reintentar and “Buscar “q””.
    Enter still submits: search never depends on the predictive layer.
- **Results page:** shared listing with title “Resultados para “q””, count,
  filters, sort (Relevancia first). No results: “Sin resultados” + Editar búsqueda,
  Limpiar búsqueda, category chips. Results error: “No pudimos cargar los
  resultados” + Reintentar.

### Floating dock (phone)
Fixed, centred, max 480 px, 24 px side margins, 12 px + safe area from the bottom.
White pill (radius 40, 0.5 px hairline, soft shadow), 6 px padding, four 56 px
items: Inicio, Catálogo, Carrito (with count), Cuenta. Selected: gold fill, dark
text. Shown on home, collections, search, favourites, account and editorial pages. In a
short viewport (§5) it is not fixed: it closes the page, after the footer.

### Product card (`MonettaProductTile`)
White card, 0.5 px hairline, radius 12, soft shadow, hover lift. Photo inset 8 px
on `#FAFAFA` (4:5 grid, 1:1 compact). Caption 12 px from the photo: optional
eyebrow (“Sobre pedido” or “Envío inmediato”, gold text), brand (Inter 600), name
(Inter 400 muted, 2 lines / 1 compact), price (Inter 700) + struck compare-at.
- Favourite: 48 px target, top-right of the photo, outline heart → filled
  gold-text heart; `aria-pressed`.
- Quick add “+”: 40 px white circle in a 48 px target at the photo's lower-right
  edge. One buyable variant: adds directly (spinner while pending). Several:
  opens the quick view and requires a choice. Sold out: no “+”.
- Sale: red pill “−N%” top-left, only for a genuine `compare_at_price > price`.
- Sold out: white veil (66%) and an “AGOTADO” seal; the card still opens.
- “Desde $x” when variants have different prices.
- No “NUEVO” badge (see §9).

### Listing (collections, brands, search)
Breadcrumbs · Playfair title · live count (“58 piezas”) · shortcut chips (bag
styles on Bolsas; categories with counts on brand pages; categories and styles on
the full catalog) · toolbar (Filtrar y ordenar with active count; sort select from
768) · removable chips + “Limpiar todo” · sidebar or drawer · grid · load more
(“Se muestran 24 de 58 piezas”, progress line, “Ver más piezas”, a real link to
`?page=2`).

**Phones.** The title row is the page bar (above); breadcrumbs and the toolbar row
are hidden, because the bar carries back, the count, search and the filters icon. What
sits above the first product is the bar, one scrolling row of shortcut chips (when the
scope has any) and the removable chips (only while filters are active). The grid is
edge to edge: two columns share the viewport with a 12 px gap, equal-height cells,
the focus ring drawn inside the card at the screen edge. Filters and sort stay in the
drawer, the URL keeps all state, and the browser's Back restores each step.
- Facets: Disponibilidad, Entrega (Envío inmediato / Sobre pedido), Categoría,
  Estilo de bolsa, Marca, Color (swatch dots), Precio (Desde/Hasta in pesos).
  Counts show what each value would return given the other facets; zero-count
  values are disabled unless selected. Facets that make no sense in the scope are
  hidden (category on category pages, brand on brand pages).
- Sidebar applies each change immediately and keeps focus and scroll; the drawer
  edits a draft and shows “Ver N piezas” / “Sin resultados con estos filtros”.
- Empty with filters: “Sin resultados” + Limpiar filtros + Ver todo el catálogo.

### Product page
Order (app hierarchy): gallery → brand eyebrow (link to the brand) → name (h1) →
price with “MXN” (+ compare-at and badge when genuine) → “El envío y los descuentos
se calculan en el checkout.” → availability line → options → quantity + Agregar al
carrito → Otras formas de comprar (Comprar ahora; Apartar por WhatsApp) → service
rows (shipping, returns, original) → accordions (Descripción open, Detalles, Envíos
y cambios) → Escribir por WhatsApp → Reseñas (Loox slot) → Más de {marca} →
Vistas hace un momento. The three sections after the purchase panel use the
product-section heading (Inter 600; §3).
- **Recommendation rails** (`product_screen.dart _Rail`): tiles 52vw wide (≤ 260 px
  on large phones) with a 12 px gap, the next tile peeking; the photo is 4:5 and
  fills the frame on white (`photoInset: 0`), with the favourite at its top-right
  corner and the “+” 4 px from its bottom-right corner; the caption is brand, a
  two-line name and the price. Every tile of a rail has the same height (the tallest
  caption sets the row). Home's “Novedades” keeps the compact tile (36vw, square
  photo, one-line name) under its Playfair heading. Tablet shows 3.2 tiles, desktop 4
  (5 from 1200 px) with previous/next buttons.
- **Availability line** (dot + text): Disponible (green dot) · Envío inmediato ·
  Sobre pedido: se envía 5 a 7 días después del cierre de pedido (gold dot) · Esta
  opción está agotada / Agotado por ahora (red dot).
- **Options.** Native radios styled as chips (text, with ✓ and fill when selected;
  struck + “Agotado” when sold out) or 32 px swatches in 48 px targets, but only when
  every variant names one reliable colour (the app rule: no “/” bicolours). The
  legend shows the chosen value. Selecting updates price, availability, photo,
  buttons and `?variant=` (replaceState).
- **Primary action.** 52 px ink button; phone: the same action lives in the purchase
  dock (bar grey, 8 + 48 + 8 px + safe area). Pending: spinner + “Agregando…”,
  `aria-busy`, second clicks ignored. Error: red message under the button
  (`role="alert"`) and a toast; the cart is unchanged. Sold out: “Agotado”,
  `aria-disabled`.
- **Comprar ahora:** adds, then opens the checkout handoff.
- **Apartado box** (dashed border): manual WhatsApp request; dialog states the
  reference deposit ($400 menudeo / $800 mayoreo, 20 days) and that sending the
  message reserves nothing and charges nothing; message preview + Copiar mensaje.
  Sold out: “Preguntar por disponibilidad”.
- **Synthetic notice** on demo-only states (prototype only).

### Quick view
Phone sheet / desktop dialog (max 920 px, image left). Starts without a selection
when opened from “+” on a multi-variant product (“Elige una opción”). “Ver
detalles completos” carries `?variant=`.

### Cart
- **Line:** 88/112 px photo (variant photo), brand eyebrow, name (link with
  `?variant=`), “Color: …”, unit price (+ compare-at), stepper (48 px buttons, max =
  inventory limit), Eliminar (undo toast), line total when quantity > 1, limit
  message when capped.
- **Drawer** (tablet/desktop, 460 px; full width on phones if opened): “Carrito
  (n)”, lines, subtotal with MXN, note that shipping, taxes and wholesale discounts
  are calculated in Shopify checkout, Continuar al checkout, Ver carrito. Opens
  after an add with the new line highlighted.
- **“En tu bolsa” sheet** (phone after add): line, subtotal, Ver carrito, Seguir
  comprando.
- **Page:** phone: the page bar (back · “Mi bolsa” · “N artículos”); tablet and
  desktop: “Mi bolsa” + count under the global header; summary (Subtotal, Ahorro frente al precio anterior
  when real, Envío “Se calcula en el checkout”, Total estimado with MXN, wholesale
  note, Continuar al checkout, “Pago procesado por Shopify”); phone/tablet checkout
  bar (Total estimado + “Ir al checkout”). Empty: “Tu bolsa está vacía” + Volver a la
  tienda + Ver favoritos + Novedades rail.
- **No shipping threshold or progress bar** (see §9).

### Handoff dialogs
Checkout, account, WhatsApp/apartado, external catalogs, partner catalogs,
community groups and social networks open a dialog that names the real
destination and what Shopify or the third party does there. Checkout lists the
exact variants and states that no order, reservation or payment happened.

### Feedback
- Toasts above the bottom control: ink (success) or sale red (error), optional
  action (“Deshacer”, “Ver favoritos”), mirrored to a live region.
- Live regions: polite `#status-live`, assertive `#alert-live`.
- Empty states: 64 px circle mark, Playfair title, short body, actions.

### Footer
`--color-bar` band: wordmark, description, WhatsApp button; Comprar, Ayuda,
Monetta columns; © and policy links. No payment-brand logos.

## 8. Accessibility requirements

- Landmarks: header, nav (categories, dock), main, footer, prototype aside; one
  `h1` per page; a visually hidden `h1` on home.
- Skip link “Saltar al contenido” is the first tab stop.
- Focus: 2 px ink outline with 2 px offset (white ring + shadow on photos); custom
  controls delegate the ring to their visible surface.
- Targets: 48 px for icon buttons (page-bar back, search and filters included),
  steppers, favourite and quick add; 44 px chips and options; 52 px primary buttons.
- Pinned chrome (WCAG 2.2 “Focus Not Obscured”): `scroll-padding-top/bottom` are the
  measured height of whatever is pinned above and below (§5), so a focused control, its
  text and its ring stay clear of the strip, header, page bar, dock, purchase bar and
  checkout bar at any size they take. A control taller than the band the bars leave (a
  product card in a 320×568 phone) is centred by the browser and its edges run under
  the bars: that case is unavoidable and only its centre is held to the standard. The
  bar is not a second `banner` landmark; its title is the page's `h1` (or plain text when
  results own the `h1`), its count is a polite live region, and the filters button names
  how many filters are active.
- Horizontal scrollers (product rails, chip rows, gallery thumbnails, the tablet category
  row): keyboard focus brings the focused item fully into view (`lib/scrollers.js`; a rail
  with mandatory snapping takes the card to its snap position, the others move the
  least that clears `scroll-padding-inline`). The target is clamped to the scrollable room, so
  an item that must clear a fade needs real end padding in the CSS (the category row has it).
  Pointer focus never moves a scroller.
- Focus is judged by what is painted, not by what the CSS declares or what `elementFromPoint`
  returns: a mask over the container or a clip by the container's own box leaves the link on top
  and the outline in the stylesheet while the ring loses edges and the words fade. The checks
  read the ring's four sides from a screenshot and compare the focused link with a second capture
  of the page without the container's mask.
- Headings: one `h1` per page in every state, including the search page with its
  suggestions open, with no results and with the results failing to load (axe
  `page-has-heading-one` is part of the gate).
- Focus placement: after navigation the heading takes focus, except when the page
  placed it itself (an empty search focuses its field).
- Dialogs: `role="dialog"`, `aria-modal`, labelled; focus moves in, Tab is trapped,
  Escape and the backdrop close, focus returns to the trigger, the page is `inert`.
- Forms and toggles: native radios for variants, checkboxes for facets, `select`
  for sort, labelled inputs; `aria-pressed` on favourites; `aria-current` on
  current navigation, thumbnails and active shortcut chips.
- Images: product photos in cards are decorative (the link names the product);
  gallery photos are described; logos carry the brand name.
- Contrast per §2; gold is never used for small text on white.

## 9. Web adaptations and their reasons

| Decision | Reason |
| --- | --- |
| Desktop/tablet hero = photo panel + copy panel instead of a full-width landscape crop | The only hero photograph is portrait (736×981, the file the live site also uses); a 1440 px landscape crop would upscale it about 1.9×. The panel keeps it crisp and gives desktop an entry without text over the photo. Phones keep the app's photo + search pill. |
| Search lives in the header on tablet/desktop | The plan's direction; avoids a duplicate field over the hero. |
| Genuine compare-at price and “−N%” on cards and product page | The plan asks for genuine compare-at prices; the app currently hides them on cards. Shown only when `compare_at_price > price`. |
| No “NUEVO” badges | With the app's 30-day window, 208 of 311 live products (67%) would carry it, which turns the badge into noise. Newness lives in Novedades and the “Más nuevas” sort. |
| “Sobre pedido” / “Envío inmediato” as a gold eyebrow and availability line | Both are real merchandising data (description text and tags); an eyebrow keeps them distinct from discount badges and from Labeler badges. |
| No shipping threshold or progress | The app's $1,499 constant is not a real store rule; shipping and discounts stay with Shopify. |
| Quantity selector on the product page | Required for the web; the app has none. |
| Beauty brands as an external-catalog panel | Dior, The Ordinary, Laneige, Rhode, Summer Fridays and Olaplex have no Shopify products; a brand grid link would lead to empty pages. |
| Filter URLs use Shopify parameter names | URLs map directly onto Search & Discovery and stay shareable and Back-safe. |
| Reviews shown as labelled samples | Real reviews come from Loox; no verified badges or aggregate rating are drawn. |
| “Mi bolsa” page title with “Carrito” in navigation | Kept from the app. |
| Prototype strip and demo panel | Prototype-only affordances; not part of production. |
| Phone page bar in place of the global header on collections, search and bag | The app's interior pages use one editorial bar (back · title · actions); the web's header, breadcrumbs, title, shortcuts and filters stacked about 236 px above the first product. Tablet and desktop keep the global header and breadcrumbs |
| Search icon in the collection bar | The app reaches search from Home; a web visitor who lands on a listing has no other one-tap way in. It costs no height |
| Style-shortcut row kept on phones (first product 52.8 px lower than the app's collection) | The shortcuts are the web's links to style collections (SEO and discovery); the app exposes them on Home and in the filter sheet. They scroll away; only the bar is pinned |
| Result counts visible | The app shows the count to administrators only; the brief asks to keep counts, and they announce filter changes |
| Hearts, genuine compare-at prices and discount badges on grid and rail tiles | Same rule as every web card (§7); the app hides them in its full-page grids and rails |
| The bar's arrow leaves the screen instead of stepping through filter history | The app's filters are local state; the web's are URL history entries that the browser's Back must keep restoring |
| Nothing pinned below 480 px of height, at any width | A pinned strip, bar and dock left 14 px of content at 320×200 and 39 px at 360×225, 164 px of a 375 px landscape bag and 54 px of a 1024×200 window. The page already carries the buttons the bars repeat (inline add, bag summary), so the bars give way; the dock follows the footer; the desktop columns tuned to the pinned header flow with the page |
| The tablet category row keeps its fade and gets end padding; its focus ring is drawn inside the link | The fade is part of the design (“there is more”). Without room at the end the last link cannot leave it, and a ring outside a 44 px scrolling row loses its top and bottom edges |
| Content stays inside the safe region; photographs and bar backgrounds still bleed | A cut-out hides text and controls, not a photograph; the app's `SliverSafeArea` protects the grid, so does the web |
| While suggestions replace search results the bar's title is the heading | The only `h1` sits in the hidden results; the bar already says “Buscar”, which is what the screen shows. A visually hidden twin would duplicate it for screen readers |
| Five recommendation tiles across from 1200 px | Keeps desktop tiles near the catalog grid's size (the app has no desktop layout) |
| “Reseñas” uses the product-section heading | It sits between two sections that use it; the app has no reviews, and its product screen uses Inter for every section title |
