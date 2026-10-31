# Monetta web — Shopify implementation handoff

How to build the reviewed design ([`DESIGN_SPEC.md`](DESIGN_SPEC.md), prototype in
`design-prototype/`) as an Online Store theme for monetta.mx. The approach, release
and rollback rules come from [the redesign plan](../MONETTA_WEB_REDESIGN_PLAN.md);
this document adds the page-by-page mapping, settings, assets, data and behaviours
an engineer needs.

**Two kinds of statements, kept apart:**

- **Design decisions (settled by the prototype):** layout, tokens, component
  anatomy and states, copy patterns, responsive and accessibility behaviour.
- **Production behaviours to verify:** anything that depends on the live store,
  its apps, its plan or its data. These are marked **[verificar]** and collected in
  §11. The prototype only simulates them.

---

## 1. Starting point and workspace

- Theme: a fresh copy of the live theme. The 2026-10-17 audit saw **Atelier 3.5.0**
  live (ID 149125824663) and an unpublished “Copia actualizada de Atelier”
  (ID 151218847895). **[verificar]** Re-list themes before starting; both IDs are
  dated observations, never targets.
- Work in a new repository folder `storefront-theme/` (not `web/`, not `shopify/`,
  not `design-prototype/`). Version the pulled baseline before editing.
- Upload work as a **new unpublished theme** (for example
  “Monetta Web Redesign — Preview”), record its ID, and use only that ID.
- Keep merchandising in Shopify: no hardcoded product IDs, prices, counts or brand
  lists in Liquid.

### Shared assets to add

| File | Content (from the prototype) |
| --- | --- |
| `assets/monetta-tokens.css` | `src/styles/tokens.css` custom properties and `@font-face` rules |
| `assets/monetta-base.css`, `assets/monetta-components.css` | The relevant parts of `base.css`, `components.css`, `pages.css`, scoped to Monetta classes so third-party widgets and payment buttons are not restyled |
| `assets/Inter-{Regular,Medium,SemiBold,Bold}.woff2`, `assets/PlayfairDisplay-Regular.woff2` | From `design-prototype/public/fonts/` with their `OFL.txt` (consider subsetting to Latin for size) |
| `assets/monetta-*.js` | Small modules: predictive search, facets, cart drawer, quick add / quick view, gallery, favourites, toasts. Port behaviour, not the prototype's renderer (Liquid renders markup) |
| `snippets/icon-*.liquid` | The Material Icons paths and stroke icons in `src/lib/icons.js` |

Theme settings: body and buttons → Inter; headings and editorial → Playfair Display;
colours and radii from `DESIGN_SPEC.md` §2/§4. **[verificar]** whether Atelier's
font picker can use the bundled files; otherwise load them through the token
stylesheet and set the theme font settings to matching fallbacks so no third font
appears. Audit every `ai_gen_block_*` on the current home for hardcoded fonts.

## 2. Page → template, section and block map

| Page / view | Template | Sections (in order) and blocks | Prototype reference |
| --- | --- | --- | --- |
| Header (all pages) | `sections/header-group.json` | `announcement-bar` (optional, only a verified current offer) · `header` with blocks: logo, search (predictive), utilities (account, favourites, cart), `menu` (category row) · phone `menu-drawer`. Phone variants by template: **collection, search and cart** render no `header` and use the page bar below; **product** renders back + search · logo · account + cart (§4) | `src/components/shell.js` |
| Phone page bar | `snippets/page-bar.liquid`, rendered by the collection, search and cart templates (phone only, via CSS) | Back link, `h1` (or plain-text title), optional count line, actions (search link, filters button) or trailing count | `src/components/page-bar.js` |
| Footer (all pages) | `sections/footer-group.json` | `footer` with blocks: brand text, WhatsApp button, link lists (Comprar, Ayuda, Monetta), policy links | `shell.js` footer |
| Phone dock | `snippets/mobile-dock.liquid` rendered from `layout/theme.liquid` | Hidden on product and non-empty cart templates (template name check) | `.dock` |
| Home | `templates/index.json` | `monetta-hero` · `product-rail` (Novedades) · `monetta-style-tiles` · `monetta-collection-cards` · `featured-collection` grid (Selección Monetta) · `monetta-brand-logos` + external-catalog panel · `monetta-story` · `monetta-social` · Loox reviews section/app block (Experiencias de clientes) | `src/pages/home.js` |
| Collection, category, brand | `templates/collection.json` (optional `collection.brand.json`) | `main-collection` with blocks: breadcrumbs (tablet up), title + count (the page bar's title and count line on phones), shortcut chips (setting-driven), toolbar (filters button, sort; tablet up — the page bar's filters icon replaces it on phones), active filters, facets (sidebar ≥1200 / drawer), product grid using the shared card (edge to edge on phones), load more + `paginate` fallback, empty state | `src/pages/listing.js`, `collection.js` |
| Product | `templates/product.json` | `main-product` with blocks: gallery (media + thumbnails), vendor/brand link, title, price (with compare-at, badge), availability (metafield-driven), variant picker, quantity, buy buttons (add to cart + dynamic checkout), apartado, service rows, collapsible tabs (Descripción, Detalles, Envíos y cambios), WhatsApp link · Loox reviews `@app` · `product-recommendations` (Más de {marca}, §4 “Recommendation rails”) · recently viewed (optional JS, same rail) | `src/pages/product.js` |
| Quick view | Section Rendering of a `quick-view` section for a product, or a product card variant picker | Same variant, price and add path as the product page | `src/components/quick-view.js` |
| Search | `templates/search.json` + `sections/predictive-search.liquid` | `main-search` (phone page bar “Buscar” + filters, field, results heading + count, facets, sort incl. relevance, grid, empty and error states) | `src/pages/search.js`, `search-ui.js` |
| Cart page | `templates/cart.json` | Phone page bar (back · Mi bolsa · count) · `main-cart-items` (lines) · `main-cart-footer` (summary, checkout, `content_for_additional_checkout_buttons`) · empty state + Novedades rail | `src/pages/cart.js` |
| Cart drawer | `snippets/cart-drawer.liquid` | Lines, subtotal, notes, Continuar al checkout, Ver carrito | `cart-ui.js` |
| Favourites | `templates/page.favoritos.json` on a new page `/pages/favoritos` | `main-favorites` (client-rendered from `localStorage` handles via `/products/{handle}.js`) | `simple-pages.js` |
| Mayoreo | `templates/page.mayoreo.json` (keep `/pages/mayoreo`) | hero, wholesale discount panel, steps, terms, catalogs (links), FAQ, community | `simple-pages.js` (Mayoreo) |
| Story | `templates/page.historia.json` on a reviewed handle **[verificar]** | hero, timeline, trust list, contact panel | `simple-pages.js` (Nuestra historia) |
| Contact | keep `/pages/contact` and its template | intro, WhatsApp button, social links, FAQ | `simple-pages.js` (Contacto) |
| Account | Shopify customer accounts (hosted) | Header link to `{{ routes.account_url }}` | `simple-pages.js` (Cuenta) |
| Policies | Shopify policy pages | Footer links only | `simple-pages.js` (policies) |
| 404 | `templates/404.json` | message, two actions, Novedades rail | `notFoundPage` |

Reuse Atelier's native product card, variant picker, media gallery, facets and
cart logic where they can take these classes and states; replace only blocks that
cannot inherit the tokens.

## 3. Section settings (merchant-editable)

| Section / block | Settings |
| --- | --- |
| `monetta-hero` | `image_mobile` and `image_desktop` (image_picker; use each image's focal point as `object-position`), `eyebrow`, `heading` (desktop panel only), `text`, two buttons (`label`, `link`), facts as blocks (`icon` select, `text`). Phone shows image + search pill only. |
| `product-rail` | `heading`, `collection`, `products_to_show` (4–12), `link_label`, `link_url` (default `/collections/all?sort_by=created-descending`) |
| `monetta-style-tiles` | `heading`, `link`; blocks: `image` (transparent PNG/WebP), `title`, `collection`; optional final “Todas las bolsas” block (`link`) |
| `monetta-collection-cards` | `heading`; blocks: `image`, `title`, `collection` (cover crop from the focal point) |
| `featured-collection` (Selección Monetta) | `eyebrow`, `heading`, `collection`, `products_to_show` (4), link |
| `monetta-brand-logos` | `heading`; blocks: `logo` (image), `brand_name` (alt text), `collection`; external panel: `heading`, `text`, buttons (`label`, `url`, opens new tab) |
| `monetta-story` | `image`, `eyebrow`, `heading`, `text` (richtext), primary button, secondary link (Vende con Monetta) |
| `monetta-social` | blocks: `image`, `label`, `handle`, `url` |
| Reviews | Loox app block settings **[verificar]** |
| `main-collection` | shortcut mode (`styles`, `categories`, `brand categories`, `none`), shortcut blocks (`label`, `link` or filter value, optional `image`), products per page (24), sidebar from 1200 (checkbox) |
| `main-product` | show quantity, show apartado (checkbox), apartado copy, WhatsApp number, service rows (blocks: icon, text), accordions (blocks: title, source: description / metafield / page) |
| `product-recommendations` / recently viewed | `heading` (defaults “Más de {vendor}” and “Vistas hace un momento”), `products_to_show` (4–8), link to the brand collection |
| Mayoreo / Story pages | Text and lists as blocks, or metaobjects `app_partner_program`, `app_about`, `reseller_catalog` if their production availability is confirmed **[verificar]** |

Home sections stay independently reorderable and hideable. Editorial copy that
already exists as metaobjects (`docs/EDITORIAL_CONTENT_METAOBJECTS.md`) should be
read from them rather than duplicated, once confirmed.

## 4. Behaviour specifications

### Cart
- Add: `POST /cart/add.js` with `{ items: [{ id: variantId, quantity }] }` and
  `sections` for the drawer/count; render Shopify's returned cart (totals,
  automatic discounts), never local arithmetic.
- One request at a time per control: disable (`aria-disabled`, `aria-busy`) and
  show “Agregando…”; ignore further clicks until the response.
- Success: open the drawer (≥768) with the new line highlighted, or the “En tu
  bolsa” sheet (<768); announce “Agregado al carrito: {producto} ({opción})” in a
  polite live region.
- Errors (422 sold out, quantity limits, network): message under the button with
  `role="alert"`, plus a toast; selection and cart unchanged.
- Quantity: `POST /cart/change.js` by line key; disable “+” at the available
  quantity Shopify reports; removal shows “Deshacer” (re-add the same variant and
  quantity).
- Line identity is the exact variant; never substitute an option.
- Checkout: the cart form `name="checkout"` posts to Shopify Checkout. Keep
  `content_for_additional_checkout_buttons` on the cart and `payment_button` on the
  product page below “Agregar al carrito” **[verificar]** which accelerated methods
  are enabled.

### Quick add and quick view
- “+” appears only on cards with something to buy. One buyable variant → add
  directly; several → quick view with no preselection and “Elige una opción”.
- Quick view and product page share variant picker, availability, price and add
  code. “Ver detalles completos” links to `/products/{handle}?variant={id}`.

### Variants
- Changing a variant updates price, compare-at, availability line, media (variant
  image first), buttons and `?variant=` with `history.replaceState`.
- Swatches only when every variant maps to one reliable colour; otherwise text
  chips. Sold-out variants stay selectable and read “Agotado”.

### Search
- Predictive: `GET /search/suggest?q=…&resources[type]=product,query&resources[limit]=5&section_id=predictive-search`
  (debounce ~160 ms; show a skeleton only after ~120 ms; abort stale requests).
- Keep the form a real `GET /search` form so Enter works without JavaScript and
  when suggestions fail. Results URL: `/search?q=…&type=product` (+ facets, sort).
- Recent searches are local to the device; offer “Borrar historial de búsqueda”.
- **One `h1` in every state.** Empty search and results that failed to load: the bar's
  “Buscar” is the `h1`. Results (with or without matches): the results heading is the
  `h1` (“Resultados para “q””) and the bar title is plain text. While the suggestions
  replace the results the results heading is hidden, so give the bar title
  `role="heading" aria-level="1"` for that time and remove it when the results return
  (on tablet and up the bar is visually hidden in that state, not `display: none`, so the
  heading stays in the accessibility tree and the field does not move). Run axe on all
  five states: `page-has-heading-one` fails in the suggestions and error states otherwise.

### Filters and sort
- Use storefront filtering URLs and the Section Rendering API; `pushState` for
  each sidebar change and each drawer “Ver N piezas”, so Back restores the previous
  state. Keep facet inputs and focus stable across updates.
- Pagination: “Ver más piezas” appends and updates `page` with `replaceState`; the
  button is also a normal link to `?page=n`.
- Restore scroll on Back (the prototype stores `scrollY` in `history.state`).

### Phone page bar and back arrow
Design: `DESIGN_SPEC.md` §7 “Page bar”. Below 768 px the collection, search and cart
templates render a pinned bar instead of the `header` group; from 768 px the bar is
only the title row.
- Markup: a back link (`aria-label="Volver"`), the page `h1` (on search results the
  `h1` is the results heading, and the bar title “Buscar” is plain text), an optional
  count line (`aria-live="polite"`), and the page's actions: a search link and a
  filters button (`aria-haspopup="dialog"`, `aria-label` naming the active count) that
  opens the existing facets drawer; the cart shows its item count at the right.
- Place it as a direct child of the page's tall wrapper, not inside the title block:
  `position: sticky` stops at its parent's edge. The prototype wraps the title block in
  `display: contents` on phones for that reason.
- Reserve it for focus and anchors with the **measured** height, not a constant (see
  “Pinned chrome, short viewports and the safe region” below): the bar grows to 97.3 px
  when its title wraps at 320 px, and a fixed 76 px left 5 px of the focused link under it.
- **Back arrow.** It leaves the screen. Filters and sort push history entries (so
  Back restores them); the arrow must skip them. The prototype stores `idx` (entries
  in this visit) and `entry` (the index where the current screen began) in
  `history.state` and calls `history.go(-(idx − entry + 1))`; with `entry` 0 (the visit
  began on this page) it goes to the parent URL: `/` for collections, search and cart,
  `/collections/guess` (Bolsas) for a style collection. If history did not move within
  500 ms it follows the parent URL, so the arrow is never dead. **That fallback belongs to
  the click that armed it.** Count every navigation of the document (link, `popstate`, an
  in-place address change, `pageshow` with `persisted`) and let the fallback act only if the
  count is the one it captured: comparing addresses (`location.href === from`) takes the
  visitor out of the restored screen when they press Forward, or reopen the same product,
  inside the 500 ms. The prototype's `leaveScreen()` in `src/lib/router.js` is the
  reference. **[verificar]** In a
  multi-page theme each filter change is a document or Section Rendering update:
  keep the same counters in `history.state` through `pushState`, and restore the
  fallback when the page is opened from outside the store.
- The browser's Back keeps stepping through filters and sort one at a time.
- Search: when it opens empty from another screen it focuses its field; the router
  must not move focus to the heading afterwards.

### Pinned chrome, short viewports and the safe region
Design: `DESIGN_SPEC.md` §5. Three rules that must travel to the theme together:
- **Measure what is pinned.** A small script (`src/lib/chrome.js`, ~70 lines) writes
  `--pinned-top` (lowest edge of the sticky/fixed header group and page bar) and
  `--pinned-bottom` (height of the fixed dock, purchase bar or checkout bar) on `<html>`;
  CSS sets `html { scroll-padding-top: calc(var(--pinned-top) + 16px); scroll-padding-bottom:
  calc(var(--pinned-bottom) + 16px) }`. Re-measure on `resize`, `orientationchange`, web-font
  load (`document.fonts` `loadingdone`), class changes on `body`, section re-renders and with a
  `ResizeObserver` on the bars **observed by `border-box`** (the dock grows with the home
  indicator through its padding, which the default content box never reports). Count an
  element only while its computed `position` is `sticky` or `fixed`. In a Shopify theme the
  header group is a section: observe the group's wrapper, and re-run after the theme editor
  re-renders it.
- **Unpin when the viewport is short, at any width.** `@media (max-height: 480px)` — not
  limited by width: a version that stopped at 1023px left 54px of a 1024×200 window to the
  page. Header group and page bar `position: static`; the dock `position: static` after the
  footer; the purchase bar and the checkout bar `display: none` with the inline add button
  (`.buy-inline`) and the cart summary's checkout button taking over. **Every desktop rule that
  sizes or pins something against the header must give way in the same block**, because
  its formula assumes a header that stays (strip + header + category row = 146px): the
  sticky filter sidebar (`position: static; max-height: none; overflow: visible`), the sticky
  product panel and bag summary (`position: static`), and the gallery's viewport-fitted
  `max-width` and thumbnail `max-height` (`none`). Left alone they collapsed at 1280×200 (viewer
  0×0px, thumbnails 7px, filters 23px). Above 480px of height nothing changes. Keep this block
  below every rule it overrides. Verify at 320×200, 360×225 and 640×400 (zoom equivalents), at
  667×375, 812×375 and 844×390 (phones on their side) and at 1023/1024/1280/1440 × 200/360/480 (a
  desktop window with its tools open), on both sides of 480/481 and of 1023/1024.
- **Stay inside the safe region.** Keep `viewport-fit=cover`; define `--safe-left/right`
  from `env(safe-area-inset-left/right)` and `--edge-l/r = max(gutter, inset)`; use the edges
  for the container, every full-bleed row (negative margin = the edge, padding = the edge), the
  bars, drawers (panel padding), sheets, dialogs, the toast and the skip link. The edge-to-edge
  grid is `margin-inline: calc(inset − edge)`. Photographs and bar backgrounds may bleed;
  text and controls may not. Test with Chromium's `Emulation.setSafeAreaInsetsOverride`
  (44 px at both sides) — and then on a real device, which nothing here replaces.
- **Keyboard in horizontal scrollers.** The browser leaves a focused rail card, chip or
  thumbnail half outside its scroller (and a rail with `scroll-snap-type: mandatory` pulls itself
  back). On `focusin` with `:focus-visible`, scroll the item's own scroller so the item is fully
  visible: to the item's snap position when the scroller snaps, otherwise the least that clears
  `scroll-padding-inline` (`src/lib/scrollers.js`). Give chip rows, thumbnails and the tablet
  category row (`12px 12%`, clear of its fade) a `scroll-padding-inline`. The target is clamped
  to the scrollable room: `scroll-padding` adds none, so a last item that must leave a fade needs
  real end padding.
- **The category row (tablet and desktop) clips and fades; build it for that.** It is a 44px
  `overflow-x: auto` row. (1) On tablets (768–1023px) the last 12 % fades out
  (`mask-image: linear-gradient(90deg, #000 88%, transparent)`): give the row `padding-right:
  max(gutter − 12px, inset, 12% + 8px)` so the last link can scroll out of the fade, and
  `scroll-padding-inline: 12px 12%` so any focused link stops before it. (2) Draw the focus ring
  of its links **inside** them (`outline-offset: −4px`): outside, the row's own clip removes the
  ring's top and bottom edges at every width from 768px. (3) On desktop make the row as wide as
  its links (`width: fit-content; max-width: min(100%, content-max)`) and let its own
  `margin: 0 auto` centre it, not `justify-content: center`: when the links overflow a little
  (1024–1059px, or with a side inset) the row becomes as wide as the window and scrolls from
  its padding, while centring would split the overflow between both sides, the start side out
  of reach and under the inset. Where the links fit the positions equal the centred ones to the
  thousandth of a pixel; an earlier version with auto margins on the first and last item fixed
  the overflow but moved every link by one layout unit (1/64px), which only a pixel
  comparison with no tolerance caught.

### Product header on phones
`product_header.dart`: back and search · wordmark (centred) · account and bag, 48 px
targets after a 4 px edge inset on each side. Below 768 px the `header` section on the
product template shows exactly those five controls (menu and favourites hidden). The
account link is `{{ routes.account_url }}` (the prototype's `/account` stands for the
hosted Shopify sign-in), search is `{{ routes.search_url }}` and the field should be
focused on arrival, the bag keeps its count badge (a link to `/cart` on phones). From
768 px the header is the global one.

### Recommendation rails
- “Más de {marca}” (`product-recommendations`, ≤ 8 tiles) and “Vistas hace un
  momento” (recently viewed from `localStorage`) are product-section headings:
  Inter 600, 17 px phone / 20 tablet / 22 desktop (the same role as “Reseñas”).
- Tiles: width `min(52vw, 260px)` on phones, 4:5 photo that fills the frame on white
  (no inset), favourite at the photo's top-right corner, “+” 4 px from its
  bottom-right, brand, two-line name, price. Tiles of a rail are equally tall: make each
  list item a flex container and the card fill it. Tablet shows 3.2 tiles, desktop 4
  and 5 from 1200 px.
- Home's “Novedades” keeps the compact tile (36vw, square, one-line name) under a
  Playfair heading; do not reuse the compact tile on the product page.

### Favourites (guest)
- Store product handles in `localStorage` (`monetta:favorites`); render via
  `/products/{handle}.js`; show “Ya no está disponible” for 404s with “Quitar”.
- If storage is unavailable, keep favourites in memory and say so on the page.
- Copy states the device-only scope; cross-device sync is a separate feature.

### Apartado and WhatsApp
- `https://wa.me/528261066868?text=…` in a new tab, with the message from
  `ApartadoRequest` (product, option, price with MXN, product URL, deposit terms,
  “no reserva inventario…”, attribution code). Nothing is reserved or charged by
  the theme. **[verificar]** the deposit amounts with the business before launch
  (the live site says $400 menudeo / $800 mayoreo, 20 days).

### External catalogs and social links
- Label as “Ver catálogo”/“Catálogo externo”, open in a new tab with
  `rel="noopener"`. **[verificar]** each destination; menu and home use different
  links today.

## 5. Asset sizes and responsive images

| Slot | Recommended source | Rendered | `sizes` |
| --- | --- | --- | --- |
| Hero, phone | 1080×1440 (3:4) or larger, light, no text | 100vw × 220–280 px, focal point | `100vw` |
| Hero, desktop panel | **New landscape asset** ≥1600×1000 | 58% of ≤1440 × 340–460 px | `(min-width: 1024px) 58vw, (min-width: 768px) 55vw, 100vw` |
| Product media | ≥1600 px long edge, 3:4, light ground, whole product | Cards ≤330 px; gallery ≤600 px wide | cards `(min-width: 1200px) 260px, (min-width: 768px) 33vw, 50vw`; gallery `(min-width: 1024px) 45vw, (min-width: 768px) 52vw, 100vw` |
| Style tiles | 600×600 transparent | 112–300 px | `(min-width: 1024px) 25vw, 33vw` |
| Collection cards | 1200×1500 (4:5) | ≤460 px | `(min-width: 768px) 33vw, 73vw` |
| Brand logos | SVG, or PNG cropped to the artwork | ≤220×40 px | fixed |
| Story image | 1200×900 | ≤560 px | `(min-width: 768px) 45vw, 38vw` |
| Social art | 440×420 | ≤240 px | fixed |

Use `image_url: width:` with `image_tag: widths:`; set width/height to avoid
layout shift; eager-load the hero and the first row only; lazy-load the rest.

## 6. Data fields and ownership

| Data | Owner / source of truth | Notes |
| --- | --- | --- |
| Title, description, media, variants, prices, compare-at, availability | Shopify product admin | Always rendered from Shopify; no theme copies |
| Brand | **New** product metafield `custom.marca` (single line or metaobject) | `vendor` is unreliable: 34 of 311 products say “Monetta” (2026-10-17). The app's normalizer and `app.brand_override` can seed it **[verificar coverage]** |
| Category | **New** `custom.categoria` (Bolsa, Cartera, Reloj, Tarjetero, Set…) | `product_type` has ~24 spellings; `app.category_override` exists **[verificar]** |
| Bag style | **New** `custom.estilo` (Crossbody, Tote, De hombro, Satchel, Hobo, Clutch, Mini, Muñequera) | Style collections (`totes`, `crossbodys`, `hombro`) stay as merchandising collections |
| Colour (filter) | **New** `custom.color` list, or the `Color` variant option where present | Only show the facet once coverage is accurate |
| Delivery | **New** `custom.entrega` (`Envío inmediato` / `Sobre pedido`) | Today: “ESTE MODELO ES SOBRE PEDIDO…” sentences in 56 descriptions and the “Envío inmediato” tag on 66 products. Move both to the metafield; Labeler may also carry these badges **[verificar]** |
| Facts (Medidas, Tipo, Incluye correa…) | Description today | Optional metafields later; the prototype parses the description |
| Reviews | Loox | No static ratings in the theme |
| Badges | Labeler (app embed) + theme sale badge | Define precedence (§7) |
| Editorial copy | Section settings or existing metaobjects | Mayoreo/story/contact |
| Favourites, recent searches | Visitor's browser | Device-only |

Configure Search & Discovery filters for availability, price, `custom.entrega`,
`custom.categoria`, `custom.estilo`, `custom.marca`, colour. Product-data changes
are a separate migration with a before/after report and rollback data.

## 7. Integrations

### Loox (reviews)
- Product page: Loox reviews app block directly after the purchase panel, before
  recommendations (prototype “Reseñas” section). Home: Loox carousel/widget in the
  “Experiencias de clientes” slot with the “LO QUE DICEN” eyebrow and section
  heading provided by the theme.
- Cards: no star ratings in this design. If added later, use Loox's own rating
  block; never draw static stars.
- Style Loox through its settings first; scope any CSS to Loox containers.

### Labeler (badges)
- Badges belong in the card media's top-left slot (where the sale badge sits) and
  next to the product price/availability on the product page.
- Precedence: one badge per card. Sale (`compare_at_price > price`) or a Labeler
  badge — choose one rule with the business **[verificar]**; “Sobre pedido” /
  “Envío inmediato” stay as the eyebrow/availability line, not as an extra pill.
- Inventory alone must not overwrite a Labeler merchandising label.

### Other embeds
Booster Page Speed Optimizer and Microsoft Clarity are enabled in the current
theme **[verificar]**; test them in the preview before changing load strategies.
Analytics: avoid duplicate `add_to_cart` events from the custom cart code.

## 8. Checkout and account boundaries

- **Checkout** is Shopify's: address, shipping options, taxes, discounts (including
  automatic wholesale discounts) and payment. The theme only hands over the cart.
  Branding (logo, colours, fonts where supported) is set in the checkout and
  accounts editor; theme CSS does not reach checkout. **[verificar]** plan-dependent
  options (custom fonts, extensions).
- **Customer accounts** are Shopify-hosted (`/account` redirects). No custom login,
  orders or addresses pages in the theme. Match logo and colours in the accounts
  branding settings **[verificar]** account mode (new vs. classic).
- The prototype's checkout and account dialogs are explanations, not designs for
  those surfaces.

## 9. URL continuity

| URL | Handling |
| --- | --- |
| `/` | Redesigned in place |
| `/collections/all` | Full catalog; “Novedades” = `?sort_by=created-descending` |
| `/collections/guess` | Keep: it is the **Bolsas** collection despite the handle |
| `/collections/guess-1` | Keep: the Guess brand collection |
| `/collections/carteras`, `/collections/carteras-1` | Both live with the same 82 products (different order). Menu and home use `carteras-1` in the prototype; consolidate only with a reviewed redirect |
| `/collections/relojes`, `/collections/relojes-1` | Both live with the same 19 products; same rule |
| `/collections/totes`, `/collections/crossbodys`, `/collections/hombro` | Keep; validate contents |
| `/collections/coach`, `/collections/michael-kors`, `/collections/steve-madden`, `/collections/tommy-hilfiger` | Keep as brand pages |
| Empty beauty collections (`anne-klein`, `christian-dior`, `laneige`, `olalplex`, `rhode`, `summer-fridays`, `the-ordinary`) | Do not link from the brand grid; external catalog panel instead |
| `/products/{handle}` (+ `?variant=`) | Keep; canonical without parameters |
| `/search?q=…&type=product` | Keep; facets as storefront filtering parameters |
| `/cart`, `/pages/mayoreo`, `/pages/contact`, `/policies/*` | Keep |
| `/pages/favoritos` | New page |
| Story page | New handle after reviewing existing pages **[verificar]** |

Filter parameters used by the design: `filter.v.availability=1|0`,
`filter.v.price.gte` / `filter.v.price.lte` (pesos), `filter.p.m.custom.entrega`,
`filter.p.m.custom.categoria`, `filter.p.m.custom.estilo`,
`filter.p.m.custom.marca`, `filter.p.m.custom.color`; sort `sort_by=manual |
created-descending | price-ascending | price-descending | relevance` (search).

## 10. Implementation acceptance (from the prototype)

- Visual: tokens, type roles and states match `DESIGN_SPEC.md`; compare against the
  captures in `fidelity-2026-10-18/screenshots/` (390, 768, 1440) and the
  app · before · after pairs in `fidelity-2026-10-18/comparacion.html` (375 and 440).
- Behaviour: the browser checks in `design-prototype/verify/check-journeys.mjs`
  describe the expected flows (search → filters → Back, quick view variant
  continuity, rapid double click, quantity/removal/undo, empty-cart recovery,
  failure feedback, phone dock rules). Re-run the equivalent checks against the
  preview theme.
- Phone fidelity: `design-prototype/verify/check-fidelity.mjs` states what the phone
  pages must show (the page bar's controls and order, the budget of chrome above the
  first product, the product header's five controls, the recommendation heading role,
  tile width, ratio and name lines, the arrow versus Back). Port those assertions to
  the preview theme at 375, 390 and 440 px.
- Audit fixes: `design-prototype/verify/check-audit-fixes.mjs` (gate D11, names
  `GPT-01 … GPT-06`, `A1`) states what must hold: no focused control, text or ring under a
  pinned bar (real Tab, hit test of the painted stacking, pixels of the screenshot); the arrow's
  fallback never undoes a Forward; one exposed `h1` and no axe violation in the five search
  states; the scroll reserve equal to the real bar height; free viewport in short viewports;
  controls and text inside the safe region with 44 px emulated insets. Port them to the
  preview theme; they run against any served URL
  (`node verify/check-audit-fixes.mjs --url=…`).
- Reaudit fixes: `design-prototype/verify/check-reaudit-fixes.mjs` (gate D11, names `RE-01`,
  `RE-02`) adds what the first set missed. Short windows are tested **on both sides** of the
  limits they introduce (1023/1024 px wide, 480/481 px tall), with the five pages, the desktop
  columns (computed `position`, gallery size) and the actions (add to bag, bag checkout,
  filters, search, browser Back and Forward with scroll restored, footer focus). The category row
  is walked with Tab **without activating the skip link** and back with Shift+Tab, at 768, 812,
  1023, 1024 and 1440 px and with 44px emulated insets, and every link is judged by what is
  painted: the ring read at its four sides from the screenshot, and the link compared
  pixel by pixel with a capture of the same page without the container's mask. Port both to
  the preview theme; `node verify/check-reaudit-fixes.mjs --url=… --grep=RE-02` runs part.
- Accessibility: zero serious/critical axe findings, keyboard paths, dialogs and
  reduced motion as in `VERIFICATION.md`.
- Performance: field targets from the plan (LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1);
  none were measured by the prototype.

## 11. Production behaviours to verify before launch

1. Live and draft theme IDs; contents and owner of the existing unpublished copy.
2. Atelier block names, card and facet implementation; Horizon-style theme blocks.
3. Font loading through theme settings vs. the token stylesheet; no stray fonts in
   generated home blocks.
4. Metafield definitions and coverage for brand, category, style, colour, delivery;
   Search & Discovery configuration.
5. Labeler and Loox placement, styling hooks and precedence; their behaviour after
   theme-editor reloads.
6. Wholesale automatic discounts in cart and checkout, including dropping below a
   threshold after removal.
7. Deposit amounts and apartado terms; WhatsApp number; external catalog URLs.
8. Accelerated checkout methods, checkout/account branding options for the plan,
   customer account mode.
9. Shipping offers (only the first-order offer is known to be real, per the app
   team) before any shipping message.
10. Embeds (Booster, Clarity, consent) with the fixed bottom controls on phones;
    chat widgets must not cover the dock or purchase dock.
11. Real-device checks: iOS Safari and Android Chrome (safe areas, keyboard,
    toolbars), VoiceOver and TalkBack. Include the pinned phone page bar with the
    browser toolbar collapsing, the screen-level back arrow after several filter
    changes, a phone in landscape with a notch (the 44 px insets here are Chromium's
    emulation) and the browser's own zoom at 200 % and 400 % on a laptop (the 320×200,
    360×225 and 640×400 checks are CSS-pixel equivalents, not that control), plus a desktop
    window with its developer tools docked at the bottom (the 1024–1440 × 200–480 checks are
    Playwright viewports).
12. Analytics continuity and attribution (the app tags carts with `_channel` and
    related attributes; decide whether web carts need equivalents).
