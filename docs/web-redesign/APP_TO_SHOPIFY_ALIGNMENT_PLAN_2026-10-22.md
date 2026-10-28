# App → Shopify design alignment plan

Prepared 22 October 2026. Scope: analysis and implementation plan for the existing Shopify staging storefront.

## Recommendation

Complete and consolidate the existing warm boutique design in `storefront-theme/`. The app and storefront already share tokens, fonts, artwork, and substantial component work. The next iteration should resolve inconsistencies, extend the design to remaining customer-facing pages, and verify responsive shopping journeys.

Use the current Flutter implementation as the reference for visual roles. Adapt navigation, density, and page composition to browser input and larger viewports. Retain Shopify Liquid sections, snippets, JSON templates, and native commerce behavior. This fits [Shopify’s theme architecture](https://shopify.dev/docs/storefronts/themes/architecture).

## Evidence and confidence

Reviewed directly:

- `design-system/monetta.tokens.json`, `design-system/build.mjs`, `lib/app/theme.dart`, and `lib/features/boutique/boutique_tokens.dart`.
- Product-card typography in `lib/features/catalog/product_tile.dart`.
- Shopify layouts, template inventory, home section configuration, generated CSS, and `monetta-app-alignment.css`.
- Existing specification and the October 22 app-alignment report.
- Saved October 22 screenshots: `artifacts/app-web-alignment-2026-10-22/after/inicio.png` and `producto-mobile.png`.

The recorded destination is `monetta-staging.myshopify.com`, draft theme `192125304866`. The preview URL could not be accessed through the web tool during this analysis. Screenshots and prior deployment reports are historical evidence, not a fresh confirmation of the remote theme. No current iOS/Android runtime was launched. Implementation should begin with new app/browser captures and remote theme identification.

The workspace contains substantial existing edits. This task adds only this plan; implementation should preserve and inventory those edits before touching shared files.

## Current findings

| Finding | Evidence | Planned response | Priority |
|---|---|---|---|
| Warm palette and responsive type tokens already exist on both platforms | Shared manifest, Flutter adapter, generated Shopify token block | Preserve and make them the authoritative implementation reference | P0 |
| Earlier web specification still documents white canvas, black actions, and older type sizes | `docs/web-redesign/DESIGN_SPEC.md` vs current manifest | Update active specification; clearly label previous visual rules as historical | P0 |
| Product-card names differ from the app | App uses `boutiqueText`; web uses `h3.card__name`, caught by blanket serif heading selector | Apply typography by component role; default card labels to Inter, product-page names to Playfair | P0 |
| Existing October 22 report records an earlier request for all headings to be serif | App-alignment report | Record the card-label exception explicitly during visual review; avoid silently treating the previous choice as accidental | P0 |
| Multiple layout paths can produce inconsistent secondary pages | Redesigned templates use `monetta.liquid`; remaining templates can use `theme.liquid` | Audit and extend shared branding to contact, informational pages, collection index, search states, and 404 | P1 |
| Saved captures mix languages | Home/Catalog/Contact and Buy it now appear alongside Spanish copy | Review menu data, locale strings, accelerated checkout language, and footer labels; distinguish theme-owned copy from store-managed copy | P1 |
| Some additions bypass geometry tokens | Alignment CSS uses 16px tile radii, 8px discount-field radius, 40px save buttons | Reconcile intentional component exceptions; make interactive hit areas at least the shared 48px target | P1 |
| Token validation reports stale Flutter output | `node design-system/build.mjs --check` | Fix deterministic formatting in generation/check pipeline | P1 |
| Token staleness is formatting-only in this checkout | Temporary generated file differs only in wrapping `manifestSha256`; hash and values match | Do not misdiagnose this as color or typography drift | P1 |
| Token metadata remains provisional | Manifest status is `proposed`; source notes pending original artwork/font identification | Record current implemented palette and fonts as this iteration’s baseline, with provenance intact | P1 |

The October 22 report already records home editorial modules, brand normalization, variants, saved products, recent views, and discount handling. Verify these features; do not estimate them as new builds. Saved/recent products are browser-local according to that report and should not imply account synchronization.

## Visual contract

| Role | App baseline to carry into web |
|---|---|
| Page canvas / bars | `#FBF8F2` / `#F7F3EC` |
| Raised surface / warm panel / tile | `#FFFFFF` / `#F3EADF` / `#F4EEE5` |
| Main / supporting text | `#211B16` / `#73665D` |
| Primary action | Brown `#745237`, white text, pill shape, 52px control height |
| Dark action | `#2D1E14`, ivory text |
| Decorative gold / accent text | `#C5A052` / `#805C32`; keep gold out of small text on ivory |
| Sale / success | Semantic red `#A3342B` / green `#3B7B4A` with their corresponding surfaces |
| Screen headings | Playfair Display 400, 26 / 30 / 36px |
| Section headings | Playfair Display 400, 23 / 27 / 30px |
| Product-page title | Playfair Display 400, 25 / 29 / 32px |
| Campaign heading | Playfair Display 400, 32 / 40 / 52px |
| Controls, prices, card labels | Inter; role-specific weight and line height from manifest |
| Spacing | 4, 8, 12, 16, 24, 32, 48, 64px |
| Geometry | Card/control 12px, tile 10px, sheet 20px, pill 999px; explicit exceptions documented |
| Motion | 180 / 280 / 480ms for shared interaction roles; reduced-motion alternatives |
| Brand and imagery | Existing Monetta wordmark and app artwork; contained product images, deliberately cropped editorial photography |

Type sizes are compact / medium / expanded. Match semantic role rather than assigning a font solely because an element is an HTML heading. Keep browser heading hierarchy meaningful. Preserve Spanish/Mexico copy and actual Shopify currency formatting.

## Responsive adaptation

| Width | Layout and behavior |
|---|---|
| Below 360px | 16px gutters; one product column where required by the existing token; avoid compressing labels and controls |
| 360–767px | 20px gutters; two product columns; compact header; drawer navigation and filter sheet; one contextual bottom action area |
| 768–1023px | 32px gutters; three product columns; expanded search and navigation as space permits; test tablet portrait and landscape |
| 1024–1279px | 40px gutters; four product columns; desktop navigation; proposed two-column product and cart layouts |
| 1280px and above | 48px gutters; 1440px maximum content width; maintain readable text widths |

Mobile keeps the app’s recognizable navigation language. On product pages, the purchase action takes priority over the navigation dock; on a populated cart, checkout takes priority. Account for browser safe areas and keyboard appearance. Desktop should use persistent top navigation, visible search, and pointer/keyboard controls. Horizontal product rails need visible controls and keyboard access as well as touch scrolling.

## Page-by-page plan

| Surface | Work to complete | Acceptance |
|---|---|---|
| Header, footer, navigation | Consistent wordmark scale, warm surfaces, active states, icon style, Spanish labels; responsive header composition | All primary destinations reachable with touch and keyboard; no duplicate or overlapping fixed actions |
| Home | Refine existing hero, novedades, styles, collections, brands, story, and social sections; maintain app photography and hierarchy | Desktop composition feels intentional; phone offers clear shopping entry points; missing optional content leaves no empty modules |
| Collection and search | Shared card style, collection imagery, count, filters, sort, empty results, predictive search | Filters/sort survive navigation as intended; keyboard focus and back navigation work; long names and missing images remain usable |
| Product | Shared serif title, contained gallery, Inter price/labels, brown purchase CTA, variants, factual details, availability and related products | Changing variants updates image/price/stock correctly; out-of-stock and loading/error states remain clear; one primary purchase hierarchy |
| Cart | Consistent typography, quantity controls, discount feedback, summary and checkout action; desktop summary beside line items | Cart state and totals remain authoritative from Shopify; quantity changes, invalid codes and errors do not create misleading feedback |
| Saved and recent products | Bring existing browser-local modules into the same grid and state design | Clear empty state, current prices on reload, honest persistence expectations |
| Contact, policies, editorial pages, 404 | Shared shell, heading roles, readable text width, form styling, focus/error states | No abrupt return to a visibly different theme when leaving the shopping pages |
| Account and checkout boundary | Identify theme-owned pages versus Shopify-hosted surfaces; assess available branding settings | Document reachable branding options and handoff appearance after verifying store configuration |

Checkout/account customization capability is an implementation discovery item. Do not assume storefront CSS controls hosted checkout or customer accounts. Keep dark mode outside the first web alignment milestone; the manifest provides only partial dark-role definitions and the current web baseline is light.

## Delivery sequence and ownership

Estimates assume one product engineer with design/merchant review, existing assets, and staging access. Allow approximately 8–12 working days; adjust after fresh captures and the route inventory.

1. **Baseline and decisions — 1 day.** Engineer + design owner: capture current iOS/Android reference screens and matching staging routes at 390px and 1440px; inventory templates/layouts and local changes; verify remote draft; settle card typography and document deliberate app/web differences. Deliver a comparison matrix and updated visual contract.
2. **Foundations and shared components — 2–3 days.** Engineer: fix generator formatting check; apply explicit type roles; reconcile radii, spacing, touch targets and state styles. Consolidate alignment overrides into component ownership after regression checks. Deliver a component specimen page covering cards, buttons, chips, fields, headings and dialogs.
3. **Shopping-page composition — 2–3 days.** Engineer + design reviewer: refine header/home, catalog/search, product and cart against the contract. Preserve completed merchandising work. Deliver side-by-side mobile and desktop captures, including error/empty/loading states.
4. **Coverage and content — 1–2 days.** Engineer + merchant: align remaining templates; resolve language/menu content; verify missing images, collection mappings and factual product data. Document hosted account/checkout branding scope and outstanding content dependencies.
5. **Validation and staged handoff — 2–3 days.** Engineer + reviewer: run automated checks and real-browser shopping journeys; resolve regressions; package draft preview, screenshots, known limitations and rollback reference. Publishing is a separate release decision after review of the completed draft.

Primary implementation locations: `design-system/build.mjs`; `storefront-theme/assets/monetta-{tokens,base,components,pages,theme,app-alignment}.css`; `layout/monetta.liquid`; relevant `sections/monetta-*.liquid`, `snippets/monetta-*.liquid`, and templates. Update `docs/web-redesign/DESIGN_SPEC.md` with the final contract.

Keep generated files generated. The current pipeline generates prototype CSS and Flutter tokens; Shopify receives CSS through `scripts/port-css.mjs`. Verify the Shopify output as well as the generator outputs. Review the port script before running it because this checkout contains storefront-specific work.

## Acceptance and release evidence

- **Visual:** matched app/web captures for home, collection, product, cart and navigation; widths 320, 390, 768, 1024 and 1440px; approved reasons for responsive differences. Review current screenshots against actual app rendering, not stale golden images alone.
- **Accessibility:** visible focus; keyboard-operable menus, search, filters and dialogs; correct labels and announced cart feedback; no focus hidden by sticky UI; 200% zoom; reduced motion; 48px shared interaction target. Validate rendered contrast in addition to manifest contrast.
- **Commerce:** available/unavailable variants, missing media, long names, zero results, empty cart, quantity edits, removed inventory, invalid and applicable discount codes, failed requests, and checkout handoff. Use staging fixtures for transactional tests.
- **Performance:** capture before/after mobile measurements on the same routes; proposed targets LCP ≤2.5s and CLS ≤0.1 under an agreed repeatable test setup. Check interaction responsiveness in real browsing; field INP cannot be established from a small staging session. Reserve media dimensions, use responsive images, and avoid lazy-loading the primary hero/product image.
- **Engineering:** token generation/check and Shopify token parity pass; no newly introduced Theme Check issues; no Monetta JavaScript console errors in tested flows; supported browsers include iOS Safari, Android Chrome and desktop Safari/Chrome.
- **Theme editor:** section reorder/reload and optional content blocks work without stale event handlers or broken layouts.
- **Handoff:** verified draft theme identifier, file manifest/backup, before/after captures, test results, and remaining issues. The previous report lists 187 Theme Check errors and 64 warnings inherited from the base; rerun and classify the current baseline instead of claiming a clean theme.

## Validation performed for this plan

Ran the existing token check. Every declared contrast pair passed, but the generated Flutter file failed the byte-for-byte freshness check. A temporary regeneration showed only a line-wrap difference around the manifest hash; token values and hash match. No storefront implementation or deployment was performed as part of this analysis.
