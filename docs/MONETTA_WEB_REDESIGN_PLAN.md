# Monetta: mobile app to production web redesign

**Date:** October 17, 2026  
**Deliverable:** Design and implementation plan; implementation and publication are separate work.  
**Target:** [monetta.mx](https://monetta.mx), including traffic arriving through www.monetta.mx.  
**Direction:** Bring the current mobile app's boutique identity to a responsive Shopify storefront, using the existing Atelier theme as the foundation.

The website should feel like the same Monetta at every screen size: the actual gold wordmark, Playfair Display editorial headings, Inter shopping controls, light photography, white space, softly rounded product cards, and restrained gold accents. Desktop should give customers more room to browse, compare, and purchase. The production design should remain editable through Shopify.

## 1. What the audit established

These findings come from the checked-out app, its image references, the public storefront, and authenticated Shopify CLI reads. They are observations as of this audit, rather than assumptions about a future implementation.

| Area | Verified finding | Consequence for the redesign |
| --- | --- | --- |
| Production identity | www.monetta.mx redirects to monetta.mx; Shopify reports `fakcei-n9.myshopify.com`; storefront currency is MXN. | Keep the existing domain and Shopify routing. |
| Live theme | CLI lists **Atelier**, ID **149125824663**, as live. Downloaded theme metadata identifies version **3.5.0**. | Start from a fresh copy of this theme and its settings. |
| Existing draft | **Copia actualizada de Atelier**, ID **151218847895**, is unpublished. Its contents and purpose were not audited. | Create a separately named redesign preview during implementation; leave this draft available for its existing work. |
| Website fonts | Theme settings use Source Sans Pro for body, Newsreader for headings, a system serif for subheadings, and Inknut Antiqua for accents. | Replace all typography roles deliberately, including cart and buttons. |
| Custom homepage | The index template contains multiple `ai_gen_block_*` blocks alongside standard sections. Public HTML also contains additional font overrides. | Audit those blocks individually; changing global font settings will not produce complete consistency. |
| Commerce foundation | Product, collection, and search templates already use native product cards, filters, variant selection, buy buttons, and recommendations. | Adapt these components while retaining their Shopify behavior. |
| App integrations | Theme settings enable Loox, Labeler, Booster Page Speed Optimizer, and Microsoft Clarity embeds. Shopify Inbox and Clarity Brand Agents embeds are disabled. | Record integration behavior before changing presentation; test the enabled embeds in the preview. |
| Navigation | Bags use `/collections/guess`, while the Guess brand uses `/collections/guess-1`. Wallet and watch links also have different handles in different homepage/menu positions. | Build an explicit route map. Labels and handles must be treated separately. |
| External categories | Perfumes and beauty currently include Google Drive catalog links. Some menu entries share a destination while homepage entries differ. | Keep a clear route to those catalogs and verify their destinations; do not present them as an on-site purchasable collection without Shopify products. |
| Wholesale | The public wholesale page describes automatic cart discounts and separate retail/wholesale apartado amounts. | Preserve the actual discount engine and distinguish retail from wholesale copy. |
| Repository | The app is native Flutter. `web/` is a screenshot gallery; `shopify/` manages an app configuration, not a storefront theme. | Add a separate theme workspace during implementation. |

The live storefront and wholesale content can be inspected at [Monetta](https://monetta.mx/) and [Mayoreo](https://monetta.mx/pages/mayoreo). Theme ID/status were additionally verified with `shopify theme list`. Selected configuration, templates, header, and typography files were downloaded to a temporary audit directory; no theme was uploaded or published.

**Scope of evidence:** this audit inspected production HTML and selected theme source, rather than a complete rendered browser/device audit. Browser automation was unavailable in this session. App screenshots were inspected locally; some golden fixtures contain intentional missing-image or test-font rendering. Those fixture artifacts are not the intended design.

### Design source priority

1. **Current rendering code and bundled assets.** The latest relevant app commit inspected is `a72b114`, dated October 14, 2026.
2. **Current boutique components and golden references**, interpreted against that code.
3. Historical reference boards and the August screenshot gallery, for context when they agree with current components.

The main source files are [boutique tokens](../lib/features/boutique/boutique_tokens.dart), [shared theme](../lib/app/theme.dart), [home modules](../lib/features/home/home_boutique_sections.dart), [product tile](../lib/features/catalog/product_tile.dart), [floating navigation](../lib/features/navigation/monetta_floating_bottom_navigation.dart), [product page](../lib/features/product/product_screen.dart), and [motion](../lib/app/motion.dart). Current representative captures are [home](../test/goldens/ui04/inicio_440x956.png) and [collection](../test/goldens/ui04/coleccion_440x956.png).

The shared theme still contains the original square-corner editorial system. The boutique layer supplies the newer rounded shopping components. Actual component usage determines the web specification: for example, the current home and product headers explicitly use a white canvas, and home section headings explicitly use Playfair Display.

## 2. Design system to carry across

### Typography and identity

| Role | Web specification | Relationship to the app |
| --- | --- | --- |
| Wordmark | Use the existing Monetta image asset with its original proportions and color. Mobile height starts at 24 px; desktop at 32 px. | Preserve the actual brand artwork. |
| Editorial headings | Playfair Display, regular; 24–28 px on phone and 32–40 px on desktop. | Preserve the home section-heading and editorial language. |
| Product name | Inter, semibold; 24 px on phone and 28–32 px on desktop. | Follow the current product typography role. |
| Body and forms | Inter, regular; 16 px for reading copy and inputs, 14 px for compact card labels. | Keep the family while adapting browser readability. |
| Prices | Inter, semibold; 16 px on cards, 24–28 px on product detail. | Keep prices clear and separate from editorial type. |
| Controls/navigation | Inter, medium or semibold; 14–16 px. | Match app controls and shopping navigation. |
| Eyebrows/metadata | Inter, medium; 11–12 px with restrained tracking. | Retain the app's small editorial labels. |

Bundle WOFF2 versions derived from the existing licensed Inter and Playfair Display assets. Keep their OFL notices, load only the weights used, use `font-display: swap`, and preload only fonts needed in the first viewport. Verify that the browser uses the intended fonts rather than synthetic weights or fallbacks. Keep the wordmark as artwork instead of reconstructing it with a font.

### Color, geometry, and spacing

| Token | Value | Intended use |
| --- | --- | --- |
| Canvas/card | `#FFFFFF` | Page and product-card background |
| Quiet surface | `#FAFAFA` | Inset media grounds and panels |
| Search/selected surface | `#F0F0F0` | Search pill, subtle selections |
| Secondary chrome | `#F5F5F5` | Supporting bars where appropriate; home header remains white |
| Ink | `#111111` | Primary text and primary purchase button |
| Muted ink | `#6B6660` | Secondary labels |
| Boutique gold | `#C5A052` | Decorative marks and selected navigation fill with dark text |
| Gold text | `#8F6838` | Gold-colored readable labels and links |
| Sale | `#A3342B` | Genuine discount states |
| Divider | `rgba(17,17,17,.12)` | Quiet card and section boundaries |
| Radius | 12 px cards; 10 px buttons; 8 px inset media; pill for search/navigation | Follow the boutique components |
| Spacing | 4, 8, 12, 16, 24, 32 px | Base rhythm; expand major desktop section gaps to 48–64 px |
| Interaction size | 48 px minimum target; approximately 52 px primary buttons | Preserve comfortable app-sized actions |

Use the newer boutique gold for UI accents while preserving the logo asset's own color. The older shared accent `#AA7D44` should not become a second competing UI gold. Decorative gold is not the default color for small text. Product cards retain a fine border and a very subtle lift; shadows must not dominate photography.

**Launch appearance:** light mode. The app's dark palette can be documented for a later web pass after images, embedded apps, account pages, and checkout have been checked together.

### Motion

Translate the app's quiet motion into 180 ms control feedback, approximately 280 ms drawer transitions, and optional 480 ms reveals for editorial content below the first viewport. Respect reduced-motion preferences. Product grids, navigation, and purchase actions must be usable immediately. Render the hero image immediately, without an entrance animation that delays its visibility. Shopify specifically recommends keeping critical content in Liquid/HTML and avoiding animation that delays the largest contentful image. [Performance guidance](https://shopify.dev/docs/storefronts/themes/best-practices/performance)

## 3. Responsive behavior

The following sizes are proposed web specifications, subject to checking the first design milestone with real products.

| Property | Phone: below 768 px | Tablet: 768–1023 px | Desktop: 1024 px and above |
| --- | --- | --- | --- |
| Page gutter | 20 px; 16 px on very narrow screens | 32 px | 40–48 px; main content maximum 1440 px |
| Navigation | White header, menu, wordmark, search; floating shopping dock where appropriate | Header plus compact navigation | Wordmark, search pill, account/favorites/cart utilities, category row |
| Shopping dock | Inicio / Catálogo / Carrito / Cuenta | Use only if it improves touch browsing | Destinations live in header/navigation |
| Product grid | Two columns; allow one column at narrow/reflow sizes | Three columns | Three columns at 1024–1199; four from 1200 where card width allows |
| Filters | Drawer with count and clear/apply controls | Drawer | Sidebar around 240 px from 1200; drawer at narrower widths |
| Home product rail | Swipeable with a partial next card and a visible “Ver todo” link | Three visible items | Four visible items with accessible previous/next controls |
| Product detail | Gallery then information; bottom purchase dock | Stacked or balanced two-column arrangement | Gallery around 58% and purchase panel around 42%; sticky panel if it fits |
| Cart | Full-width drawer/page; bottom checkout action | Drawer plus full cart route | Drawer approximately 440–480 px; cart page with a summary column |

Breakpoints should respond to content pressure. Avoid shrinking labels or card content to force an extra column. Keep product names to two readable lines on grid cards and allow prices to wrap without colliding with badges.

On mobile, preserve the distinctive floating dock on home, collection, and search results. On a product page, the purchase dock takes its place. On the cart, the checkout action takes precedence. Account pages hosted by Shopify have their own layout. Account for `env(safe-area-inset-bottom)`, browser toolbars, the software keyboard, consent controls, and any chat widget so fixed controls never cover content or each other.

## 4. Page-by-page design

### Home

Retain the app's merchandising sequence: photograph and search, Novedades, Compra por estilo, Colecciones, Selección Monetta, Marcas, Más sobre Monetta, social content, and customer experiences. Each section remains independently editable and hideable in Shopify.

- **Phone:** keep the current compact photograph at approximately 220–280 px tall and its rounded search field near the lower edge. Follow it with the app's compact product rail and style tiles.
- **Desktop:** use a dedicated landscape crop, approximately 360–460 px tall, with the same light photographic direction. Place persistent search in the header so the hero does not need a duplicate search field. Keep the image free of baked-in promotional typography. Show four new-arrival cards, a single row of style tiles, and a three-column collection group.
- **Editorial tail:** use a balanced image/text layout for the Monetta story, a genuine wholesale entry point, approved social content, and existing Loox reviews. Retain a clean footer with contact, shipping, returns, and policies.

Do not copy the current mobile crop into every desktop ratio. Provide mobile/desktop image fields and focal points in the theme editor. An optional announcement must use a current, verified offer and must not crowd out the main navigation.

### Collections, brand pages, and catalog

Use the same card anatomy as the app everywhere: full product photograph, optional real badge, working favorite/quick-add controls, brand, product name, and price. Grid images use 4:5 frames; compact home-rail images may use square frames. Product photography uses contain behavior so straps and handles remain visible.

Above the grid, include breadcrumbs, a clear title, result count, sort, and selected-filter chips. On bags, retain Compra por estilo as a useful collection shortcut. Default filters are availability, price, brand, and category/style where reliable source data exists. Color and other facets should appear only when populated accurately.

Store filters and sorting in the URL; preserve them through refresh and browser Back. Use server-rendered pagination or accessible load-more with normal links as a fallback. An empty result should explain how to clear filters and offer a useful collection link. Shopify's storefront filtering supports these collection/search flows, including metafield filters and URL parameters. [Filtering documentation](https://shopify.dev/docs/storefronts/themes/navigation-search/filtering/storefront-filtering)

### Search

Carry the app's rounded search language into a real search form. Add predictive results with product images, names, and prices; Enter opens the full results page. Search must work without depending on the predictive interface. Design the initial, loading, results, no-results, and failed-request states. Keep keyboard behavior, focus, and clear-query actions explicit. Use Shopify search and predictive search rather than downloading the complete catalog into the browser. [Search documentation](https://shopify.dev/docs/storefronts/themes/navigation-search/search)

### Product detail and quick view

Use the current app's information hierarchy with a desktop gallery and adjacent purchase panel:

1. Brand, full product name, current price, and genuine compare-at price where applicable.
2. Variant choices, availability, and quantity, with clear selection requirements.
3. Primary **Agregar al carrito** action with pending, success, and error states.
4. A secondary purchase shortcut using the existing Shopify purchase path where appropriate.
5. Shipping/returns information, details accordions, and a separate WhatsApp apartado entry.
6. Loox reviews and Shopify product recommendations below the purchase content.

Preserve the current theme's accelerated-payment integrations, with a clear hierarchy and their actual eligibility rules. A quick-add control adds a known, valid single variant; products requiring choices open quick view or the product page. Quick view and the product page must use the same selected variant, availability checks, price, and cart behavior.

Separate **in-stock**, **sold-out**, and **sobre pedido** messaging using actual product/inventory data. Labeler currently carries merchandising information; inventory availability alone must not overwrite that information. An apartado request opens WhatsApp with the product and variant context. The UI must explain that this is a manual request and not imply that clicking reserves inventory or pays a deposit.

The public wholesale page currently distinguishes a $400 retail deposit from an $800 wholesale deposit, with a 20-day window. Treat these as current source content to reconcile with the business before launch; the mobile retail constant must not be applied indiscriminately to wholesale. [Current wholesale terms](https://monetta.mx/pages/mayoreo)

### Cart and checkout

Style the existing Shopify cart drawer and cart page with the same card, type, divider, and button system. Include item/variant details, quantity changes, removal, actual discounts, and subtotal. Show loading/errors beside the affected control. Render changes using Shopify's returned cart totals, including automatic wholesale discounts.

Shipping, tax, discount eligibility, and payment availability remain driven by Shopify. The app contains shipping constants, while the website advertises a first-order shipping offer; those are not evidence of a single universal rule. Add a shipping-progress message only after checking the real rules and exclusions.

Hand payment and address collection to Shopify checkout. Branding for checkout and customer accounts lives in a separate editor, and available extension surfaces depend on the store's plan. Exact custom-font and layout parity must be checked there; theme CSS does not carry into those hosted surfaces. [Checkout/account branding](https://help.shopify.com/en/manual/checkout-settings/customize-checkout-configurations), [extension availability](https://help.shopify.com/en/manual/checkout-settings/customize-checkout-configurations/checkout-apps)

### Account, favorites, and editorial pages

- **Account:** use the existing Shopify account entry and supported account component/routes. Match logo and supported branding settings. Avoid implementing a second authentication system. Current Shopify account pages operate separately from theme templates. [Templates and customer accounts](https://shopify.dev/docs/storefronts/themes/architecture/templates)
- **Favorites:** include working guest favorites to support the app's heart controls. Store product references locally, handle unavailable items and disabled storage gracefully, and label the behavior honestly. Cross-device sync is a separate backend feature.
- **About/contact:** bring the app's story and contact language into editable sections. Keep `/pages/contact` working; select any new about-page handle after the existing pages inventory is reviewed.
- **Mayoreo:** preserve `/pages/mayoreo`, its automatic discount behavior, catalog links, apartado terms, and WhatsApp path. Use clear steps and FAQs rather than creating a new ordering system.
- **Customer experiences:** reuse Loox's existing review data and blocks. Do not reproduce ratings or verified-review badges as decorative static content.
- **External catalogs:** keep an explicitly labeled “Ver catálogo” action for categories that still live outside Shopify, using reviewed destinations.

## 5. Shopify implementation approach

Use an adapted **Online Store theme** with Liquid, JSON templates, theme blocks, CSS variables, and small JavaScript enhancements. This is the recommended approach because the production store already has native Shopify commerce components and integrations. It keeps merchandising in Shopify and limits operational change. Shopify's architecture supports reusable sections, blocks, assets, and merchant-editable templates. [Theme architecture](https://shopify.dev/docs/storefronts/themes/architecture)

Create a future `storefront-theme/` workspace alongside the app. Keep `web/` as its existing reference gallery and `shopify/` as its existing CLI app workspace. No Flutter-web or headless storefront migration is needed for this design objective.

| Implementation area | Planned change |
| --- | --- |
| Theme settings | Map body/buttons to Inter and editorial roles to Playfair Display; set boutique colors, radii, and spacing. |
| Shared assets | Add a small token stylesheet, component styles, font assets, and focused modules for custom interactions. |
| Existing card system | Adapt the existing `_product-card` blocks and shared product-card rendering so collection, search, recommendations, and home agree. |
| Header/footer | Adapt existing theme groups; add responsive navigation, useful search, and the phone shopping dock. |
| Home | Reuse standard sections where they meet the specification; replace custom generated blocks that cannot reliably inherit the design system. |
| Product/cart | Style the existing variant picker, buy buttons, media gallery, cart updates, and error feedback instead of rebuilding their commerce model. |
| Editorial | Add a small set of reusable Monetta sections/blocks for story, style tiles, and wholesale content. Retain `@app` support where integrations need it. |
| Localization | Keep shopper copy in Spanish and theme locale files; format money through Shopify's currency-aware helpers. |

Scope CSS to intentional component classes and use existing theme variables where possible. Review every custom block for hardcoded fonts, inline styles, and independently loaded resources. Update references in preview templates as blocks are replaced. Avoid broad overrides that unexpectedly restyle payment controls or third-party review widgets.

### Data contract before building filters

The Flutter app normalizes brand/category/style on-device. A Liquid theme does not automatically inherit that Dart logic. The repository documents past catalog problems with raw `vendor` and `product_type`; those historical counts are not a current catalog audit. [Normalization documentation](../lib/data/normalize/README.md)

During implementation, inspect existing metafield definitions and a current catalog sample. Reuse reliable fields first. If gaps remain, propose consistent brand, category, silhouette, and color fields, with a documented population rule. Existing app overrides include `app.brand_override` and `app.category_override`; verify their actual production coverage before relying on them. Configure Search & Discovery filters against the canonical data. Updating product data is a separate migration from theme styling and needs its own before/after report and rollback data.

Use collection/product references in theme settings rather than hardcoded product IDs, prices, counts, or brand lists. Preserve merchant control over section order, selected collections, images, and links. Existing editorial definitions such as `app_about`, `app_partner_program`, and `reseller_catalog` are reuse candidates after verifying their production availability and readability. [Editorial content contract](EDITORIAL_CONTENT_METAOBJECTS.md)

### Route continuity

| Current route | Intended handling |
| --- | --- |
| `/` | Redesign in place. |
| `/collections/all` | Retain the full-catalog entry. |
| `/collections/guess` | Preserve the current bags destination despite its handle. |
| `/collections/guess-1` | Preserve the Guess brand destination. |
| `/collections/totes`, `/collections/crossbodys`, `/collections/hombro` | Retain style destinations and validate their current contents. |
| `/collections/carteras` and `/collections/carteras-1` | Compare publication/content before choosing the menu and homepage destination. Retain old links or provide a reviewed redirect if consolidation is justified. |
| `/collections/relojes` and `/collections/relojes-1` | Apply the same comparison before consolidation. |
| `/products/*`, `/search`, `/cart`, `/pages/mayoreo`, `/pages/contact`, policy URLs | Retain existing behavior and links. |

A new label does not require a new handle. Record any necessary redirects explicitly and preserve product canonical URLs, metadata, structured data, and sitemap access.

## 6. First-release scope and later features

| First redesigned release | Follow-up after the core release |
| --- | --- |
| Responsive shell, home merchandising, collections/brands, search, product detail, quick add, cart, and checkout handoff | Cross-device favorites and preference sync |
| Guest favorites and existing Shopify recommendations | Porting the app's explainable on-device recommendation behavior to the web |
| Existing account entry, supported branding, contact, wholesale, external catalogs, and Loox reviews | Custom account dashboard and rewards UI backed by verified production APIs |
| Accurate price/stock/discount messaging, WhatsApp apartado path | Restock subscriptions, web push, and richer notifications |
| Editable theme sections, accessibility, SEO, and analytics continuity | Optional preference onboarding, recently viewed content, and dark mode |

Any existing production rewards, notification, or wishlist integration discovered in the full audit must be accounted for before this scope is finalized. The core release should not display a control that promises an unavailable follow-up feature.

## 7. Work sequence and reviewable deliverables

Planning estimate: **15–22 working days**, approximately **3–5 weeks** for one senior engineer handling the design translation and theme implementation. This is an initial range, not a delivery commitment. It assumes usable theme access, available product photography, timely design review, and no new checkout/account backend. Catalog remediation and follow-up features can extend it.

| Milestone | Estimate | Concrete output | Completion criteria |
| --- | --- | --- | --- |
| 0. Complete baseline | 1–2 days | Full versioned theme snapshot, rendered mobile/desktop captures, current route/data/app inventory, performance baseline, merchant-settings inventory | Active commerce integrations, alternate templates, discount behavior, checkout/account limits, and rollback assets are documented. |
| 1. Design specification | 2–3 days | Web tokens and desktop/phone compositions for home, collection, product, search, and cart; shared component/state sheet | Type, crop, card density, navigation, purchase hierarchy, and error/empty states are reviewable against the app. |
| 2. Theme foundation and home | 3–4 days | Separate theme workspace, fonts/tokens, shared cards, shell, responsive home, theme-editor controls | Real data renders; sections can be reordered and edited; phone/desktop identity matches the specification. |
| 3. Shopping flows | 4–6 days | Collections/filters, search, product/quick view, favorites, cart, checkout handoff | Selected variant, stock, prices, discounts, cart changes, Back navigation, and errors behave correctly. |
| 4. Content and integrations | 2–3 days | Wholesale/contact/story content, Loox/Labeler presentation, supported account/checkout branding, consent-aware analytics continuity | Links and terms are correct; app blocks and automatic wholesale discounts still work. |
| 5. Acceptance and release preparation | 3–4 days | Unpublished theme preview, device/commerce/accessibility checks, visual evidence, release/rollback record | Acceptance criteria below pass; the preview and remaining limitations are ready for final release review. |

The first visual review should show the five principal page types together so shared typography and purchase behavior can be assessed coherently. Each later milestone should include an actual theme preview and screenshots at the agreed sizes, plus a concise list of unresolved issues.

## 8. Acceptance criteria

**Visual fidelity**

- The correct Inter and Playfair Display assets load, the real wordmark is used, and custom blocks have no accidental third/fourth font system.
- Home photography/search, rounded cards, gold selection states, and serif section headings are recognizable from the app.
- Product photography retains complete silhouettes, and real products with long Spanish names and large prices fit.
- Core layouts are checked at 375, 390, 440, 768, 1024, 1280, and 1440 px, plus narrow reflow and zoom. There is no unintended horizontal page scrolling.

**Commerce and navigation**

- Browse → search/filter → variant selection → add → quantity update → checkout works, with equivalent prices and discounts.
- Cover single-variant, multi-variant, sale, sold-out, sobre-pedido, insufficient-stock, failed-request, and empty-cart cases. Test two rapid clicks and changes while a cart request is pending.
- Verify wholesale thresholds using the actual configured rules, including dropping below a threshold after removal. Keep apartados distinct from checkout/payment.
- Browser Back restores query/filter context; direct product and collection links still work; external catalogs and policy links resolve correctly.
- Core browsing, search submission, product forms, and cart checkout have usable progressive fallbacks. App blocks survive theme-editor edits and section reloads.

**Accessibility and interaction**

- Keyboard access, visible focus, focus restoration, Escape behavior, dialog focus containment, headings, labels, and cart announcements work.
- Text contrast, readable gold labels, 48 px intended action targets, reduced motion, zoom/reflow, and screen-reader announcements are checked manually alongside an automated scan.
- Product and checkout actions remain visible above safe areas and the keyboard; floating navigation never overlaps the purchase dock or consent/chat controls.

**Performance and discoverability**

- Preserve server-rendered essential content, responsive image sizing, explicit image dimensions, and a promptly loaded hero image. Lazy-load below-fold media.
- Audit each enabled embed's cost before changing its load strategy. Keep the image, font, and first-party JavaScript budget measurable against the baseline.
- Aim for field Core Web Vitals of LCP ≤2.5 s, INP ≤200 ms, and CLS ≤0.1 at the 75th percentile, assessed separately by device class. These are release targets, not measurements achieved by this plan.
- Before launch, use repeatable lab measurements and interaction traces. After launch, inspect field data as it accumulates; a Lighthouse score alone does not establish field INP.
- Preserve canonical tags, title/description, product structured data, valid status codes, existing analytics/pixels, and consent behavior. Avoid duplicate purchase events.
- Run Theme Check and resolve introduced errors. Record inherited issues separately with their impact.

**Merchant operation**

- The owner can change banner images, collection links, section order, merchandising selections, and approved editorial text in Shopify.
- Document image crops and essential settings in a short handoff. Product/price/inventory changes continue to flow from Shopify without a theme code release.

## 9. Preview, launch, and rollback

Implementation begins by re-listing themes and pulling a **complete fresh baseline** into the separate workspace. Recheck the live ID at that time; this audit's ID is a dated observation. Version the baseline before editing. Capture a rendered baseline before removing/replacing any generated blocks.

Upload implementation work as a **new unpublished theme** with a distinctive name such as `Monetta Web Redesign — Preview`. Record its new theme ID and use that ID for subsequent uploads. Do not target either currently listed theme for implementation work by accident. Shopify's CLI supports uploading a new unpublished theme and returns a preview link. [Theme push reference](https://shopify.dev/docs/api/shopify-cli/theme/theme-push)

Keep theme changes separate from any global menu, product-data, discount, app, checkout, or account configuration changes: those settings can affect the live store even while a theme is unpublished. Track and schedule them individually. Staging is appropriate for test payments; previewing a theme on the production shop still connects to real commerce data. Any production transaction test needs a separately agreed test arrangement.

The final release package contains the preview URL, the new theme ID, passed checks, representative device screenshots, remaining limitations, and the previous live theme ID. Review this concrete package before publication. Take a final snapshot of merchant edits and reconcile settings that changed during development, then publish the approved theme.

For a theme regression, republish the recorded previous theme and verify home, product, cart, and checkout entry. Reverting a theme does not undo changes to catalog data, navigation menus, discount rules, or checkout configuration; each such change needs its own recorded prior values and reversal procedure.

After release, inspect error reports, add-to-cart success, checkout starts, search use, and conversion by device. Compare against a suitable prior period with traffic and promotions in mind; this redesign does not guarantee a conversion uplift. Perform an early operational check after launch and a broader review after sufficient field performance and commerce data is available.

## 10. Decisions and checks carried into implementation

The recommended defaults are settled for this plan: native Shopify theme, Atelier baseline, the current boutique visual language, Spanish copy, light appearance, real Shopify checkout/accounts, preserved URLs, and a separate unpublished preview.

The full implementation audit must still establish:

- The contents/ownership of the existing unpublished copy and all alternate page/product/collection templates.
- The store plan, active customer-account mode, available hosted-page branding/fonts, and required extension surfaces.
- Current canonical product-field coverage, collections with duplicate-looking handles, and which external catalog destinations are correct.
- Current shipping offers, wholesale discount rules, apartado eligibility/terms, and the data behind sobre-pedido badges.
- Available desktop photography, image focal points, live review/badge behavior, and complete embedded-script behavior in a rendered browser.
- Which home/editorial metaobjects already exist in production and how their fields can be reused without breaking the app.

These are implementation checks, not reasons to delay this planning deliverable. The next concrete implementation output is the versioned theme baseline plus the five-page responsive design specification from milestones 0 and 1.
