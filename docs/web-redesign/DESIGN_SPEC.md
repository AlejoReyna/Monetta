# Monetta web — design specification

**Status: active** for the Shopify theme in `storefront-theme/` (staging draft `192125304866` on
`monetta-staging.myshopify.com`). Updated 22 October 2026 by the app design-language pass
([`shopify-staging/design-language-2026-10-22/`](shopify-staging/design-language-2026-10-22/HANDOFF.md)).

**Source priority.** `design-system/monetta.tokens.json` (colours, type roles, geometry, layout, motion) ▸ the current
Flutter implementation (`lib/app/theme.dart`, `lib/features/boutique/boutique_tokens.dart` and the widgets named below) and
its bundled assets ▸ this document ▸ older specifications and screenshots, which are history. The prototype-era
specification of 17–18 October (white canvas, ink primary buttons, Inter product names, other type sizes) is archived
unchanged in [`history/DESIGN_SPEC_prototype_2026-10-18.md`](history/DESIGN_SPEC_prototype_2026-10-18.md); where it and this
document disagree, this document wins.

**Where the values live.** The manifest generates the token block of `design-prototype/src/styles/tokens.css` and
`lib/app/monetta_tokens.g.dart` (`node design-system/build.mjs`); the theme receives it through
`tools/style-guideline-theme/port-css.mjs`, together with the prototype's base, component and page sheets
(`assets/monetta-{tokens,base,components,pages}.css`, generated, never edited by hand). Everything specific to the theme
and to the current app is in two theme-owned sheets: `assets/monetta-theme.css` (what a server-rendered Shopify theme
needs: dialogs, forms, Shopify widgets) and `assets/monetta-app-alignment.css` (one block per component, each naming the app
widget it follows). Checks: `node design-system/build.mjs --check` (outputs current, 22 contrast pairs) and
`node tools/style-guideline-theme/port-css.mjs --check` (the theme's four ported sheets equal a fresh port:
Shopify token parity).

---

## 1. Identity and language

- **Wordmark.** The app artwork (`monetta-logo{,-2x,-3x}.png`, ≈ 3.47 : 1) at 24 px on phones and tablets, 32 px on
  desktop, 21 px in the menu drawer, 26 px in the footer. Never redrawn with a font or recoloured. The same artwork, as an
  animated GIF on the canvas colour, is the customer sign-in logo (§8).
- **Favicon.** `monetta-favicon-32/96.png`.
- **Photography.** Packshots are always whole (`contain`) on the warm tile ground with `mix-blend-mode: multiply`, so their
  white backgrounds melt into the mat. Editorial photographs (hero, collections, story) are deliberate `cover` crops. The
  home's style silhouettes and brand logos are the app's bundled artwork (`monetta-app-*.webp`).
- **Voice.** Spanish (Mexico), short and calm: “Agregar al carrito”, “Mi bolsa”, “Se calcula en el checkout”. No urgency or
  scarcity copy, no invented reviews, discounts, stock claims or delivery promises.

### Language ownership

The documents declare `lang="es-MX"`. Who owns each piece of text decides how it is made Spanish:

| Text | Owner | How it reaches Spanish |
| --- | --- | --- |
| Everything written by Monetta sections and snippets (buttons, states, headings, empty states, dates) | Theme | Written in Spanish in the theme. Dates use `snippets/monetta-date.liquid` (“22 de octubre de 2026”), independent of the store locale |
| Shopify-generated labels with a stable key: sort options (by value), the availability and price filters (by parameter) and their values, policy link names (by URL), product option names (Color, Talla…), Shopify's untouched default menu titles (Home, Catalog, Contact, Search…), the automatic all-products collection (“Products”) and the default “News” blog | Shopify, presented by the theme | Translated at display time by `snippets/monetta-label.liquid` (and the collection, blog and `<title>` logic). Anything the merchant renamed is printed as typed |
| Merchant content: renamed menu links, product titles, descriptions and options, page text, policies, block settings of merchant-built pages | Merchant | As typed. When the store language is not Spanish, Shopify-language fragments are marked with `lang` (`snippets/monetta-store-lang.liquid`) |
| Atelier sections (contact, mayoreo, cómo vender, password page) | Theme locale files | Follow the store language: `locales/es.json` exists, so they turn Spanish when the store's default language is Spanish |
| Accelerated checkout buttons (“Buy it now”), Shopify error messages, checkout, customer accounts, sign-in | Shopify | Store language only |

The staging store's default language is **English**. That is the single setting behind the remaining English (“Buy it
now”, Shopify error messages, the hosted account and checkout, the privacy policy text). Changing it is a merchant action in
Shopify Admin (Settings › Languages), together with renaming the default menus (Online Store › Navigation) and regenerating
the policies in Spanish (Settings › Policies). The theme does not change store settings.

## 2. Colour

Light appearance only; the manifest's dark roles exist for the app and are not used by the web.

| Token (`--color-…`) | Value | Use | Contrast (from the build gate) |
| --- | --- | --- | --- |
| `canvas` | `#FBF8F2` | Page ground, product cards | — |
| `bar` | `#F7F3EC` | Header, page bar, dock, purchase and checkout bars, footer band | — |
| `surface` | `#FFFFFF` | Gallery, fields, brand cells, flush recommendation tiles | — |
| `surface-warm` | `#F3EADF` | Warm panels (hero copy, story), quiet buttons, empty-state marks, applied-code chips | — |
| `surface-tile` | `#F4EEE5` | Photo mats (cards, bag lines), bag summary, comments | — |
| `ink` | `#211B16` | Text, icons, focus ring | 16.07 canvas · 15.40 bar · 14.31 warm · 14.77 tile |
| `ink-muted` | `#73665D` | Supporting text, card names, counts | 5.23 canvas · 5.01 bar · 4.66 warm · 4.81 tile |
| `action-primary` / `on-action-primary` | `#745237` / `#FFFFFF` | Principal pill (Agregar al carrito, checkout, empty-state actions) | 6.99 |
| `action-dark` / `on-action-dark` | `#2D1E14` / `#FBF8F2` | Dark pill; Atelier's black bands on merchant pages | 15.15 |
| `accent-text` | `#805C32` | Eyebrows, saved hearts, link hover | 5.67 canvas · 5.43 bar · 5.05 warm |
| `gold` | `#C5A052` | Marks only: count badges, “Nuevo” ground, active rules, quote rule. Never text | 2.32 on canvas (decorative) |
| `divider` | `#E7DCCE` | Hairlines, card ring, cell borders | — |
| `border-control` | `#8A7766` | Outlined controls and fields | 4.03 canvas · 4.28 surface (≥ 3:1, WCAG 1.4.11) |
| `navigation-active` / `-inactive` | `#8C6436` / `#211B16` | Dock and category row states (plus weight and a 2 px rule) | 4.76 / 15.40 on bar; 3.24 between them |
| `sale` / `sale-surface` | `#A3342B` / `#F6DEDA` | Card discount badge (white on sale, 6.81), product-page discount chip, errors | 6.43 canvas · 5.31 on its surface |
| `success` / `success-surface` | `#3B7B4A` / `#EAF4EC` | Availability dot, posted-comment note | 4.53 |
| `scrim` | `rgba(33,27,22,.45)` | Dialog backdrops | — |
| `on-photo` | `#F8F5EE` | Titles over photographs (with the app's legibility gradient) | — |

## 3. Typography by role

Inter (400, 500, 600, 700) and Playfair Display (400) are the app's bundled OFL files, served as WOFF2 with
`font-display: swap` (Regular, SemiBold and Playfair preloaded). Fallbacks: Georgia for the serif, `system-ui` for the sans.
Bold Playfair is never synthesised (`font-synthesis: none`).

**Typography follows the component's role, not its HTML element.** Sizes are compact / medium (≥ 768) / expanded (≥ 1024)
from the manifest.

| Role | Face | Sizes | Line height · tracking | Where (CSS hook) |
| --- | --- | --- | --- | --- |
| Campaign | Playfair 400 | 32 / 40 / 52 | 1.08 · −0.012em | Home hero tagline (`.display--hero`) |
| Screen title | Playfair 400 | 26 / 30 / 36; page bar 28 on phones; search results 22 on phones | 1.12 · −0.012em | `.display--page`, `.page-bar__title`, policy titles |
| Section title | Playfair 400 | 23 / 27 / 30 | 1.15 · −0.01em | Home and product sections (`.display--section`, `.product-section-title`), collection tiles, article cards, prose `h1`/`h2` |
| Product name | Playfair 400 | 25 / 29 / 32 | 1.15 · −0.01em | Product page `h1` (`.product-panel__name`) |
| Account row / menu row | Playfair 400 | 18 / 19 / 20; drawer rows 17 | 1.25 | Accordion titles, menu drawer rows (`monetta_side_menu.dart`) |
| Dialog and empty-state titles | Playfair 400 | 22 (dialogs), 26 (empty states) | 1.2 | `.overlay__title`, `.empty__title` |
| Body | Inter 400 | 15 / 16 / 17 | 1.5 | Running text, prose (68ch measure), Atelier paragraphs on merchant pages |
| Card label | Inter | brand 600 · name 400 muted · 14 / 15 / 16 (compact rails 12–13) | 1.25–1.35 · 0 | Product cards everywhere: grid, rails, saved list (`.card__brand`, `.card__name`) |
| Price | Inter 600 | 15 / 16 / 17 (product page 20 / 22 / 24) | 1.3 | `.price` |
| Panel title | Inter 600 | 17 | 1.25 | Bag summary “Resumen de compra”, “Otras formas de comprar” (`boutiqueTitle`) |
| Control | Inter 600, uppercase on commerce buttons, 0.06em | 14 / 15 / 15 | 1.1 | Buttons, chips |
| Navigation label | Inter 500 | 12 / 13 / 13 | 1.2 | Dock, category row |
| Eyebrow | Inter 500, uppercase, 0.14em | 11 / 11 / 12 | 1.3 | Brand above the product name, footer column labels, “Envío inmediato” |

**The card-label exception (decision of 22 October, this pass).** On 22 October, earlier the same day, every `h1`–`h6`
had been set in Playfair at the person's request, including the product-card names (an `h3`). The app's product tile
(`product_tile.dart`) sets brand, name and price in Inter (`boutiqueText`), and so do the web cards again: the name stays an
`h3` for the document outline, its look is the card-label role. For the same reason (the app's `boutiqueTitle`), two panel
titles inside commerce flows stay Inter 600 17 — “Resumen de compra” and “Otras formas de comprar” — and the footer
column labels are the Inter eyebrow. Every other heading role is the serif, as asked. This is recorded as a deliberate
exception, to be confirmed in visual review; it is one CSS block (“Type roles” in `monetta-app-alignment.css`).

Inputs use 16 px so mobile Safari never zooms on focus. The phone search results heading follows the app
(`boutiqueScreenTitle(size: 22)`), replacing the prototype's Inter 600 20.

## 4. Geometry, spacing, elevation, motion

| Token | Value | Use |
| --- | --- | --- |
| `--radius-card` | 12 px | Cards, panels, gallery, collection and brand tiles, story, article media, bag summary |
| `--radius-control` | 12 px | Fields (discount code, filters, comments), option chips, stepper, quiet buttons |
| `--radius-tile` | 10 px | Inset product photo, thumbnails, bag-line photo |
| `--radius-pill` / `--radius-chip` | 999 px | Primary, outline and dark buttons, chips, badges, search field |
| `--radius-sheet` | 20 px | Bottom sheets and dialogs |
| Bars | 0 | Header, page bar, dock, purchase and checkout bars (full width) |
| Spacing | 4, 8, 12, 16, 24, 32, 48, 64 | `--space-1` … `--space-8` |
| `--control` | 52 px | Primary and outline buttons, fields in the bag and on the search page |
| `--tap` | 48 px | Minimum for **every** tap target |
| Elevation | card `0 4px 14px #3D2B1C0F`; float `0 1px 6px #3D2B1C1F`; panel `0 24px 64px #3D2B1C2E` | Card hover, quick-add circle, dialogs |
| Motion | snap 180 ms · swap 280 ms · settle 480 ms, `cubic-bezier(.16,1,.3,1)` | Controls · drawers and sheets · photo zoom on collection tiles |

**Documented exceptions.**
- Phone purchase-dock action: 48 px inside 8 + 48 + 8 (the app's `kPurchaseDockButtonHeight`); inline purchase actions are 52.
- Menu-drawer rows: 14 px row radius and 30 px drawer corners (the app's side menu), not a token.
- Quick add and gallery tools: 40 px circles centred in 48 px targets (the app's `_QuickViewButton` anatomy).
- Option chips: 48 px (the app draws 44; the web follows the manifest's `size.tap`).
- Badges: pills of 22 px minimum height; they are labels, not targets.
- Breadcrumb links, links inside running text and the footer's legal row: inline text links (WCAG 2.5.8 exception), at
  least 24 px tall.

The card is the canvas colour with a 0.5 px divider ring (drawn as a shadow, so the box size never changes) and the soft
card shadow; hover lifts it 2 px on pointer devices only. Reduced motion (`prefers-reduced-motion: reduce`) removes
transitions, animations, smooth scrolling and the collection-tile zoom.

## 5. Responsive layout

| Width | Gutter | Product columns | Header | Product page | Bag | Filters |
| --- | --- | --- | --- | --- | --- | --- |
| < 360 | 16 | 1 | Phone header (menu · wordmark · search); page bar on collection, search and bag | One column, full-bleed gallery, purchase dock | Lines, summary, checkout bar | Drawer |
| 360–767 | 20 | 2 (listings edge to edge, 12 px gap) | As above | As above | As above | Drawer |
| 768–1023 | 32 | 3 | Tablet header: menu · wordmark · search field · utilities; scrolling category row | **One column**: gallery as a square capped at 60vh, thumbnails under it, full-width panel with inline buttons | One column; checkout bar | Drawer |
| 1024–1279 | 40 | 4 | Desktop header: wordmark · search field · Cuenta / Guardados / Carrito with labels; centred category row | Two columns (58 : 42), thumbnail column, sticky panel | Two columns (3 : 2, summary ≥ 344 px, sticky) | Drawer below 1200; sticky sidebar from 1200 |
| ≥ 1280 | 48 | 4 | As above, content max 1440 px | As above | Two columns (7 : 4) | Sidebar |

**One bottom control at a time.** Phones show the navigation dock on browsing and content pages, the purchase dock on a
product page (the purchase action outranks navigation) and the checkout bar on a non-empty bag (checkout outranks both).
The reserve for them is measured (`--pinned-top/bottom` from `monetta-core.js`), focus and anchors stop short of them
(`scroll-padding`), and under 480 px of height nothing is pinned. Safe areas: content starts at `max(gutter, inset)`;
photographs and bar backgrounds still bleed. These rules come unchanged from the prototype and the first theme delivery.

Rails (Novedades, recommendations, recent views, more from the brand) scroll by touch, show previous/next buttons from
1024 px and bring a keyboard-focused card fully into view.

## 6. Images

| Image | Treatment |
| --- | --- |
| Product photo in cards | 4:5 (1:1 in compact rails), 8 px inset, tile radius, `contain` + multiply on the tile ground; flush recommendation tiles fill a white frame |
| Gallery | White, 4:5 slides (square capped at 60vh on tablets); a product with one photograph has no thumbnail column and its viewer spans the gallery |
| Bag line | 88 / 112 px, tile ground |
| Home hero | Phone: full-bleed photo with the search pill; tablet/desktop: photo panel beside the warm copy panel |
| Style silhouettes | The app's artwork multiplied straight onto the canvas: no box, no radius (`_StyleTile`) |
| Collection tiles and index cards | `cover`, card radius, legibility gradient, serif title in `on-photo`; a collection without an image uses its first product's photo |
| Brand logos | 600 px squares cropped by a 2.45 : 1 cell (the app's grid) on a white cell with a divider |
| Story, article | `cover`, card radius, warm ground while loading |

Every `<img>` carries its intrinsic size; only the first viewport's hero and product photo load eagerly.

## 7. Components

### Shell (both layouts)
`layout/monetta.liquid` (Monetta sections) and `layout/theme.liquid` (pages built from Atelier sections and Shopify's
policy pages, which cannot choose a layout) share `snippets/monetta-head.liquid`, the Monetta header and footer groups, the
dock, the bag sheet, the saved list and the live regions. A shopper never lands on Atelier's header, footer or fonts.

- **Header.** Bar ground, hairline once scrolled; 48 px icon targets; category row from 768 with a 2 px gold rule on the
  current item. Menu labels pass through the language snippet (Inicio · Catálogo · Contacto on staging).
- **Menu drawer.** Wordmark, close, “Inicia sesión” / “Mi cuenta”, Guardados (when the browser can store it), the main menu
  and the footer menu as Playfair 17 rows with light icons.
- **Dock (phones).** Flat full-width bar: Inicio, Catálogo, Carrito (count), Cuenta; active item in `navigation-active` with
  weight and a rule.
- **Footer.** Bar band: wordmark, description, WhatsApp button; link columns with Inter eyebrow labels; © and policy links
  named in Spanish.

### Product card (`MonettaProductTile`)
Canvas card, 0.5 px divider ring, 12 px radius, soft shadow, hover lift. Photo inset 8 px on the tile ground. Caption 12 px
below: optional eyebrow (“Envío inmediato” from the tag or `custom.entrega`, accent text), brand (Inter 600), name (Inter
400 muted, two lines; one in compact rails), price (“Desde” when variants differ) and the struck compare-at price only when
`compare_at_price > price`.
- Badge, top left: “−N%” white on sale red for a genuine discount; otherwise “Nuevo” ink on gold for products created in the
  last 30 days (the app's window), only when in stock.
- Sold out: 66 % canvas veil and an “Agotado” seal; the card still opens.
- Favourite: bare heart in a 48 px target at the photo's top-right corner; filled heart in accent text when saved
  (`aria-pressed`). Shown only once the script can read the browser's list.
- Quick add “+”: 40 px circle in a 48 px target, only for products with a single buyable variant.

### Listings (collection, search)
Phone page bar (back · title · count · search · filters), shortcut chips, removable filter chips, edge-to-edge grid,
“Ver más piezas”. Tablet and desktop: breadcrumbs, title, count, toolbar (Filtrar y ordenar, sort select), sidebar from
1200. Sort options and the availability and price filters read in Spanish; Shopify's all-products collection is
“Catálogo”. An editorial image appears when the collection has one. No results: empty state with Editar búsqueda / Limpiar
búsqueda.

### Product page
Gallery → brand eyebrow → name (product-name role) → “Ver mis guardados” (quiet text action, left aligned) → price with
MXN (+ compare-at and discount chip when genuine) → “El envío y los descuentos se calculan en el checkout.” → availability
→ options (legend in the app's words: Color, Talla…; chips 48 px; swatch when Shopify gives one) → quantity + Agregar al
carrito → Otras formas de comprar (Shopify's accelerated checkout, Apartar por WhatsApp) → service rows → accordions
(Descripción, Detalles, Envíos y cambios) → Escribir por WhatsApp → app blocks → recommendations, more from the brand,
recent views. Variant changes re-render the panel from Shopify (price, stock, buttons, `?variant=`).

### Bag
Lines (tile photo, brand eyebrow, name, variant, price and compare-at, stepper with 48 px buttons, Eliminar), Seguir
comprando, summary on the tile ground (Subtotal, Descuentos aplicados when Shopify reports them, Envío “Se calcula en el
checkout”, Total estimado with MXN; amounts never break), the discount code (label, full-width field, “Aplicar código”
outlined pill, applied codes as chips, “Quitar códigos” only while Shopify holds a code, a status message that only
confirms what Shopify applied), the note, Continuar al checkout and “Pago procesado por Shopify”. Every amount is
Shopify's.

### Saved and recent pieces (browser-local)
The saved list is a dialog (header heart from 768, menu drawer and product page on phones) that states its scope: saved in
this browser only, not synced with the account or the app, price and availability read from the store each time. Empty:
“Toca el corazón de una pieza…” with Ver catálogo. Recent views and “Más de {marca}” are rails on the product page. Only
handles are stored; cards are re-rendered by Shopify.

### Secondary pages
| Page | Template / section | Notes |
| --- | --- | --- |
| Generic page | `page.json` → `monetta-page` | Breadcrumbs, screen title, prose at 68ch; optional WhatsApp + catalog actions |
| 404 | `404.json` → `monetta-404` | Empty-state anatomy, search field, Ver catálogo / Ir al inicio, optional rail (“Te puede interesar”) |
| Collections index | `list-collections.json` → `monetta-collection-list` | Editorial cards with real counts; 2 / 3 / 4 columns |
| Blog / article | `blog.json` → `monetta-blog`, `article.json` → `monetta-article` | Article cards with Spanish dates; prose; Shopify's comment form in Spanish when the blog accepts comments; empty state |
| Policies | Shopify's markup in `layout/theme.liquid` | Screen-title heading, prose measure, content marked with the store language |
| Contact, mayoreo, cómo vender | Merchant-built Atelier sections in `layout/theme.liquid` | Monetta shell; `snippets/monetta-atelier-bridge.liquid` maps Atelier's fonts, colour schemes, button and field shapes to the tokens. Block-level colours chosen in the editor (white panels, `#8C6703` headings, grey buttons on the contact page) are the merchant's and stay as set |
| Password page | `layout/password.liquid` | Bundled fonts and the bridge; form, fields and Shopify's check unchanged |

### Feedback
Toasts above the bottom control (ink, or sale red for errors) mirrored to `#status-live` / `#alert-live`; inline errors
with `role="alert"`; empty states with a 64 px mark, a Playfair title, one line and pill actions.

## 8. Hosted surfaces: checkout, customer accounts, sign-in

Theme code does not reach them. Shopify renders checkout, the new customer accounts and the sign-in page on its own
domain, styled from Shopify Admin:

| Mechanism | Scope | Plan |
| --- | --- | --- |
| Checkout and accounts editor (Settings › Checkout › Customize) | Logo, colour palette (header, main, order summary, buttons, accents, errors), heading and body fonts from Shopify's library, layout options; part of it applies to customer accounts and sign-in | All plans |
| Checkout Blocks, Checkout Branding API, Checkout and Accounts Configuration API | Corner radius, button shapes, custom fonts, per-section styles, per-surface overrides | Shopify Plus |

On staging the sign-in page was branded on 22 October from the editor (canvas `#FBF8F2`, accent `#745237`, the animated
wordmark; see [`shopify-staging/branding-signin-2026-10-22/`](shopify-staging/branding-signin-2026-10-22/README.md)).
Checkout and the account pages follow the store language (English on staging) until the store's default language changes.
The checkout page itself could not be opened by the automated browser: the storefront password gates it. Matching the
web: background `#FBF8F2`, buttons and accent `#745237`, error `#A3342B`, Playfair Display for headings if the font library
offers it (otherwise a classic serif) and Inter for body.

## 8a. Accessibility

- Landmarks and one `h1` per page, in every state; skip link first.
- Focus: 2 px ink outline, 2 px offset (inside the element where a scroller would clip it); never hidden by the pinned bars.
- Targets: 48 px minimum for every tap target (§4 exceptions are inline text).
- Dialogs: modal, labelled, focus trapped and returned, Escape and backdrop close, page inert.
- Live regions announce bag changes, saved changes and discount results; discount messages never claim a code applied
  unless Shopify returns it.
- Language: `es-MX` documents; store-language fragments marked with `lang`.
- Contrast per §2 (the build gate refuses a manifest whose pairs miss their minimum); rendered contrast checked with axe.
- Reflow at 320 px (400 % zoom), 200 % zoom at 640 px, reduced motion honoured.

## 9. Deliberate differences from the app

| Web | App | Reason |
| --- | --- | --- |
| Commerce buttons in uppercase with 0.06em tracking | Sentence case (the app passes the case it wants) | Style guide; Flutter cannot transform case, the web does it in CSS (`BoutiqueButton` note) |
| Genuine compare-at prices and “−N%” on every card | Hidden on some grids and rails | One web card everywhere; shown only when `compare_at_price > price` |
| Option chips 48 px | 44 px | The manifest's 48 px minimum target |
| Saved and recent pieces in the browser only | Synced with the account | No web account synchronisation exists; the list says so |
| One-column product page from 768 to 1023 with inline buttons, header navigation instead of the purchase dock | Purchase dock on tablets | Tablet web uses the top navigation; the purchase action is inline and full width |
| Breadcrumbs, result counts, sort select, filter sidebar | Not present | Web navigation and shareable URLs |
| Spanish labels for Shopify's untouched English defaults | Spanish app strings | The store language is English on staging; merchant-renamed labels are printed as typed |
| Merchant-built contact page keeps its block colours | No equivalent screen | Merchant content; the shell, fonts, schemes and shapes are aligned |

## 9a. XL storefront exceptions (29 October 2026)

Review implementation on unpublished staging draft **192576585762**, “Monetta buscador predictivo borrador sin public...”.
These theme-owned exceptions start at **1280px**; the generated tokens, Flutter app, search grid, compact rails and smaller
screen layouts keep their previous sizing. Implementation evidence and measurements:
[`../../artifacts/xl-storefront-2026-10-29/README.md`](../../artifacts/xl-storefront-2026-10-29/README.md).

- Collection listings use a fluid **1680px outer cap including 48px side padding**, a **232px** filter sidebar and **32px**
  separation. Product gaps are **20px horizontal / 30px vertical**. With filters: **3 columns at 1280–1439**, **4 from 1440**;
  without filters: **4 throughout XL**. Sticky filters use the shell's measured `--pinned-top` plus 16px.
- Collection guide banners are **260px** tall at XL; an empty page-head reserves 12px. Homepage carousel and other guide
  banners retain their composition. Measured first-row advance is **128.47px at 1280** and **172px from 1440**.
- Collection card bodies use **16px padding**, **17px Inter names** with two lines reserved, and **19px prices**. Empty
  delivery/brand slots reserve their line without visible or accessible invented text. Cards stretch within the row;
  prices can wrap and the view pill consumes remaining space above it, aligning bottoms without a fixed card height.
- **4:5 media retained for Carteras, Bolsas and Relojes**, always `contain`. Comparing Carteras at identical 315px card
  width showed that square frames reduce height but also reduce the portrait source images, giving up most of the visible
  wallet size increase. First-page sources include 1054×1492 and 1122×1402 images; chains and keyrings stay complete in
  both versions. Source whitespace remains; no zoom, crop or replacement was introduced.
- Collection image `sizes` describe the **inset media slot**, including sidebar presence and the 3/4-column breakpoints.
  An XL-only `<picture>` source supplies candidates through **900px** for high density screens. The shared `<img>` defaults
  and existing compact-rail call-site overrides retain their **600px** ceiling, including mobile collection cards.
- Home collections have **1168px usable row width**, **28px gaps** and approximately **371px cards**. The heading container
  is 1264px including gutters; the row has no duplicate inline padding. Home styles share this container, with a left-aligned
  **960px** row, **104px icons**, **16px labels**, and **34px** section titles for these two modules. The mobile collection
  carousel and style layout retain their existing rules.

The required interaction checks exposed a pre-existing automatic type/vendor collection bug: sorting rebuilt the query
string without its `q`. The collection section now supplies that identity to the existing sort/filter forms, preserving
the category through sorting, filter application/removal and pagination. Sorted clear-all URLs use the correct query
separator when `q` is present. These behavior corrections apply at every width.

Home registration follow-up (29 October): when the registration section is last, it meets the footer with no outer gap
at every viewport. On arrival it reveals its title, copy and button once with a 600ms fade/rise and 80ms stagger.
Content remains visible without JavaScript or with reduced motion; keyboard focus cancels the entrance immediately.
Evidence: [`../../artifacts/register-footer-2026-10-29/`](../../artifacts/register-footer-2026-10-29/).

## 10. History

| Date | Change | Record |
| --- | --- | --- |
| 17–18 Oct 2026 | Responsive prototype and audits (white canvas, ink actions) | [`history/DESIGN_SPEC_prototype_2026-10-18.md`](history/DESIGN_SPEC_prototype_2026-10-18.md), `STATUS.md`, `VERIFICATION.md` |
| 19 Oct 2026 | First theme delivery (Atelier copy + Monetta layout) | [`shopify-staging/ENTREGA.md`](shopify-staging/ENTREGA.md) |
| 20–21 Oct 2026 | Client style guide: warm manifest, brown pill, serif roles, flat dock | `docs/style-guideline-migration/STATUS.md` |
| 22 Oct 2026 | App alignment: home modules, brands, saved and recent, discount codes, Playfair for every heading | [`shopify-staging/app-alignment-2026-10-22/COMPARATIVA.md`](shopify-staging/app-alignment-2026-10-22/COMPARATIVA.md) |
| 22 Oct 2026 | Design-language pass: role-based type (card-label exception), card surface, 48 px targets, single-photo gallery fix, tablet product layout, Spanish labels, shared shell and new sections for secondary pages, discount and summary fixes, token freshness fix | [`shopify-staging/design-language-2026-10-22/HANDOFF.md`](shopify-staging/design-language-2026-10-22/HANDOFF.md) |
