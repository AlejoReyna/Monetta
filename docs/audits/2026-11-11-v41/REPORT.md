# MONETTA v4.1 product and design gap review

Reviewed **11 November 2026**, against the **current Flutter working tree**, based on commit `80735fa` plus the existing uncommitted changes. **The app partially matches the delivery; it does not yet meet v4.1 / Correction 5 acceptance.** Updating the palette, fonts and bundled assets has not completed the screen and flow migration.

The review added only audit documents, render fixtures and evidence. It did not change application behavior or production configuration.

## Authority and scope

Source of truth: `/Users/alexis/Downloads/MONETTA_Entrega_Final_v4.1`:

- `08_IA/INICIO_IA.md` and `MONETTA_UI_Contrato_IA_v4.1.json`: 50 active contracts. Correction 5 overrides conflicting earlier appearances.
- `01_documentacion/MONETTA_Documento_Maestro_UI_v4.1.md`: especially sections 003–011, 012–070 and the acceptance sections.
- `02_sistema/tokens_v4.1.json`, banner/photo inventories and `05_maquetas/png`.

Confirmed requirements are distinguished from **proposed numerical geometry** and **pending business/provider decisions**. A different proposed radius or timing is not treated as a confirmed defect. Example names, balances and membership tiers in the mockups must never be copied into real customer data.

Scope is the Flutter app in `lib/`, with its existing tests and bundled content. The Shopify Liquid theme, web prototype, deployed CMS contents and production store were not separately audited.

## What already aligns

- The current token values include pure white, gold `#A58248`, green `#3B7030`, DM Sans and Cormorant Garamond. Font files are bundled. The four navigation destinations now read Inicio / Categorías / Carrito / Cuenta.
- The asset manifest contains **33 banner exports** (32 compositions plus the B04 editorial variant), **18 home photos** and **61 icons**. The existing asset checks pass.
- Common cards open quick view; favorite actions are independent. Variant selection and authoritative add-to-cart behavior already have useful tests. Cart summaries use Shopify discounts rather than a fabricated local discount.
- Order/payment states, account data, favorites and notification inboxes have existing implementations and tests. The app does not need these foundations rebuilt.
- Contact and Wholesale **already overlay text on their hero photographs**. The Correction 5 gaps there concern artwork/copy, controls, reading size and continuation—not a missing overlay.

## Visual evidence

These pairs show the owner's reference on the left and freshly rendered current widgets on the right:

| Area | Comparison |
|---|---|
| Home | [Reference vs current](evidence/home-comparison.jpg) |
| Categories | [Reference vs current](evidence/categories-comparison.jpg) |
| Account | [Reference vs current](evidence/account-comparison.jpg) |
| Rewards | [Reference vs current](evidence/rewards-comparison.jpg) |
| Contact | [Reference vs current](evidence/contact-comparison.jpg) |
| Wholesale | [Reference vs current](evidence/wholesale-comparison.jpg) |

The paired images use top crops of expanded full-page renders; the full-page helper places navigation at the bottom of the expanded image. Use the separate [Android-sized Home viewport](evidence/viewport-home-390-1x.png) and [iOS Home viewport](evidence/viewport-home-ios-390.png) to judge viewport/navigation placement. Product tiles in these fixture renders can deliberately repeat the same image; that repetition is a harness limitation, not a finding about the real catalog. Owner sample balances are illustrative.

## Required changes

**P1** below means required before claiming v4.1 parity; it is not a claim that the existing commerce system is unusable. **P2** means shared presentation work. **Gate** means a provider/business capability still needs verification or configuration.

### F01 — P2: the new assets and design language are only partly connected

The new `assets/images/v41/` assets and `design-system/v41-assets.json` are packaged, but a scan of every Dart file under `lib/` found **no references to either path**. The actual screens still use the older `guide/` and home artwork. Thus a passing asset-presence test does not establish that the owner sees the delivered artwork. The banners also reconstruct lettering with fonts, although section 006 requires the original outlined lettering. Account rows remain serif through the `accountRow` role, while the reference uses DM Sans for those UI labels. The header's plain icon buttons and several flat panels lack the requested Glass treatment; Android uses a flat bottom bar, while iOS has a glass capsule.

Evidence: [legacy asset constants](/Users/alexis/theCode/Monetta/lib/features/boutique/guide_art.dart:21), [banner reconstruction](/Users/alexis/theCode/Monetta/lib/features/home/home_boutique_sections.dart:248), [UI type role](/Users/alexis/theCode/Monetta/design-system/monetta.tokens.json:251), [header](/Users/alexis/theCode/Monetta/lib/features/navigation/guide_chrome.dart:25), [platform-specific bar](/Users/alexis/theCode/Monetta/lib/features/navigation/monetta_bottom_navigation.dart:161). Scan results and source hashes: [audit-evidence.json](audit-evidence.json).

Acceptance: wire the authoritative assets by semantic ID, preserve accessible labels without duplicating visual text, apply UI/editorial type roles correctly, and review shared controls on both mobile platforms. Validate proposed dimensions on devices rather than treating them as immutable pixels.

### F02 — P1: Home still follows the older layout and destinations

The hero slides are Compra fácil / Nueva colección / Perfumes. v4.1 requires **B01 products / B02 brands / B03 categories**, each opening the corresponding destination. Below them the app shows Compra por estilo and Colecciones, then brands. Nueva colección is a four-card grid; its source list is capped at eight. Lo más buscado reuses that list. The required large selected product with a 40-product thumbnail rail and direct PDP opening is absent, as is the **Para ti** accordion/feed. About and other configured tail sections can render after the footer. The wholesale CTA says CONOCE MÁS instead of Comenzar a vender.

Evidence: [opening order and eight-product cap](/Users/alexis/theCode/Monetta/lib/features/home/home_screen.dart:54), [hero destinations](/Users/alexis/theCode/Monetta/lib/features/home/home_screen.dart:400), [body sequence](/Users/alexis/theCode/Monetta/lib/features/home/home_screen.dart:425), [new-collection layout](/Users/alexis/theCode/Monetta/lib/features/home/home_boutique_sections.dart:525), [wholesale banner](/Users/alexis/theCode/Monetta/lib/features/home/home_screen.dart:712). Contracts G01, G01-A, G01-B; master 012–014, 062.

Acceptance: implement the confirmed sequence, correct all three hero destinations, add the selected-product/thumbnail interaction and Para ti feed, support 40 unique products where available, and end with one B04 → services → registration → footer. The proposed featured chevrons are optional geometry; the selected-product behavior is required.

### F03 — P1: registration, footer and policy content are outdated

The common invitation says REGÍSTRATE / Consulta tus pedidos y datos de compra / REGISTRARME AHORA. It has no email field and does not display the three Correction 5 lines: **Regístrate en MONETTA REWARDS**, **ENVÍO GRATIS para siempre**, **GANA CASHBACK con cada compra**, with their specified color roles and registration halo. The footer offers Ayuda y contacto and Nuestra historia plus a pending-policy message, rather than the required Contacto / Envíos / Cambios y devoluciones / Mayoreo / Privacidad / Términos destinations. These common components also affect Wholesale and product continuations.

Evidence: [invitation](/Users/alexis/theCode/Monetta/lib/features/home/home_account_invitation.dart:51), [footer](/Users/alexis/theCode/Monetta/lib/features/boutique/client_guide_sections.dart:346), [policy placeholder](/Users/alexis/theCode/Monetta/lib/features/checkout/purchase_notices.dart:9). Master 012, 062 and Correction 5 G01.

Acceptance: implement the approved copy and hierarchy with a real registration path and preserved email on error; connect existing approved documents. Cashback wording still requires the delivery's business/integration gate. Never infer operational eligibility from a promotional line.

### F04 — P1: Categories, brands and sidebar navigation do not match the information architecture

Categories is a seven-tile directory of Crossbody/Tote/Shoulder/Handbags/Carteras/Perfumes/Accesorios. It lacks the expandable **Bolsos → Carteras → Perfumes → Calzado → Accesorios** family tree and gender/subtype branches. Brand logos are small grid tiles rather than the wide white cards. There is no dedicated all-brands directory in this flow: the sidebar's Todas las marcas invokes the full product catalog, and Home's brands Ver todas opens Categories. The sidebar lacks the requested hierarchy, account tier/balance and explicit close control, omits Mayoreo after brands, and still displays the retired share banner. Its social links lack the specified labeled Glass-circle composition.

Evidence: [directory and source list](/Users/alexis/theCode/Monetta/lib/features/catalog/categories_screen.dart:64), [directory rendering](/Users/alexis/theCode/Monetta/lib/features/catalog/categories_screen.dart:198), [sidebar links](/Users/alexis/theCode/Monetta/lib/features/navigation/monetta_side_menu.dart:194), [Home sidebar binding](/Users/alexis/theCode/Monetta/lib/features/home/home_screen.dart:618), [other sidebar binding](/Users/alexis/theCode/Monetta/lib/features/navigation/guide_drawer.dart:51). Contracts G02–G04.

Acceptance: implement the specified tree and all-brands surface, use gold category icons outside Home, wire each label to its actual set, and remove the retired sharing navigation.

### F05 — P1: collection/search controls implement a smaller filter contract

Collection filters contain sort, type, brand and availability, but no color, Recién llegados or Ofertas controls. The full catalog has color/price options, but still lacks the new/offer intersection. Collection sort supports newest and the two prices; oldest is missing. Sorting is combined with filters rather than the requested independently accessible actions. The collection page does not have the required in-scope Buscar producto capsule. Banner/header presentation remains from the earlier guide rather than the small contextual title and floating v4.1 banner. Brand browsing likewise needs the delivered B24–B30 bindings and common controls.

Evidence: [filter/sort models](/Users/alexis/theCode/Monetta/lib/features/catalog/collection_screen.dart:42), [catalog model](/Users/alexis/theCode/Monetta/lib/features/catalog/catalog_browse_screen.dart:38), [collection filter UI](/Users/alexis/theCode/Monetta/lib/features/catalog/collection_screen.dart:950), [legacy banner component](/Users/alexis/theCode/Monetta/lib/features/catalog/catalog_controls.dart:275), [brand screen](/Users/alexis/theCode/Monetta/lib/features/catalog/brand_screen.dart:121). Contracts G05–G08, G05-A, G07-A, G37.

Acceptance: supply the missing criteria, use AND for new+offers, retain the current collection/brand scope, and provide clear apply/cancel semantics. Confirm the business date for Nuevo before enabling its production filter. Alphabetical sort and the extra availability option are proposed, not mandatory additions.

### F06 — P1: the common card cannot carry the requested selected variant, and sold-out styling is wrong

`ProductCard` passes a product-level data object and opens quick view without a selected-variant argument. It has no independent color/variant swatch action. In the shared tile, availability is product-wide and the price is derived from the product's cheapest variant. This cannot satisfy the requested photo/price/stock consistency for an independently selected card color. Sold-out cards still use a **large centered white outlined capsule and image washout**. Correction 5 requires a small **black label with white text near the photo's bottom edge**. New/sale badge and heart geometry also require the v4.1 shared treatment.

Evidence: [card data and route](/Users/alexis/theCode/Monetta/lib/features/catalog/product_card.dart:113), [product-level tile data](/Users/alexis/theCode/Monetta/lib/features/catalog/product_tile.dart:328), [sold-out overlay](/Users/alexis/theCode/Monetta/lib/features/catalog/product_tile.dart:888), [heart](/Users/alexis/theCode/Monetta/lib/features/catalog/product_tile.dart:1010), [sold-out render](evidence/viewport-sold-out-390.png). Master 008 and G05/G09/G12/G35.

Acceptance: carry variant identity through card → quick view → PDP, update all displayed data together, keep heart/color taps independent, and replace the sold-out overlay everywhere. Do not add fake color options to single-option products.

### F07 — P1: quick view and PDP retain older controls and continuation

Quick view has a back chevron as well as X; G09 specifies X without a back arrow. Its photo is a gallery rather than an explicit PDP entry, and the current photo controls need to preserve the selected variant on that transition. PDP uses Descripción / Detalles / Envíos y devoluciones, a separate visible Apartar section and a related-products grid. The required **Descripción → Otras formas de comprar → Envíos → Cambios y devoluciones**, then **Relacionados → Más de la marca → Vistos hace un momento**, and common registration/footer are incomplete. Zoom supports pinch through InteractiveViewer but has no explicit enlarge/reduce/reset controls or multi-photo navigation. Shipping copy is hardcoded to 3–5 days instead of coming from approved content; do not resolve that discrepancy by inventing a policy.

Evidence: [quick-view photo controls](/Users/alexis/theCode/Monetta/lib/features/product/quick_view.dart:380), [PDP accordions and continuation](/Users/alexis/theCode/Monetta/lib/features/product/product_screen.dart:483), [zoom](/Users/alexis/theCode/Monetta/lib/features/product/product_screen.dart:779), [apartado section](/Users/alexis/theCode/Monetta/lib/features/product/product_screen.dart:1221). Contracts G09–G11 and G10-A.

Acceptance: restore the required control/section structure and selected-variant transition, use approved content, complete the three recommendation sets and accessible zoom controls. Preserve the already-tested purchase selection logic.

### F08 — P1/Gate: restock alerts do not implement the variant/email request contract

The PDP calls `createRestockAlert(product.id)` directly. There is no G12 form with the selected exhausted variant, matching thumbnail, email label/validation, consent and real existing/new-request response. The alert button remains present even when the service is unavailable, then explains unavailability after a tap. The variant must be part of the registration; a product with one available color and one exhausted color is a relevant case.

Evidence: [restock call](/Users/alexis/theCode/Monetta/lib/features/product/product_screen.dart:167), [unconditionally visible exhausted-product action](/Users/alexis/theCode/Monetta/lib/features/product/product_screen.dart:466), [controller request](/Users/alexis/theCode/Monetta/lib/app/notification_controller.dart:183). Contract G12.

Acceptance: implement the authorized channel's form/service contract with variant identity; hide dependent controls when the necessary capability is not configured.

### F09 — P1: Account lacks the Correction 5 identity and modules

The account header shows name/email, with balance in a separate Rewards row. It lacks **Miembro + actual level** and **Saldo / green real amount** in the header. Modo Mayoreo and a fixed Comparte y gana banner remain. No editable post-logout advertising slot/model is implemented. Absence of ad content should hide that slot, so an empty ad area alone is not a defect. Direcciones and Métodos de pago are always shown but open informational sheets: addresses cannot be listed/added/edited/deleted, and payment management is not available despite the visible management-style row. Help is combined with Contact instead of exposing the required approved help/policy content.

Evidence: [module rows and share banner](/Users/alexis/theCode/Monetta/lib/features/account/account_screen.dart:287), [information-only actions](/Users/alexis/theCode/Monetta/lib/features/account/account_screen.dart:587), [header](/Users/alexis/theCode/Monetta/lib/features/account/account_screen.dart:795), [Rewards row](/Users/alexis/theCode/Monetta/lib/features/account/account_screen.dart:1265). Contracts G18, G26–G30.

Acceptance: compose the real identity/balance header, remove retired actions, add the configured editorial slot, connect supported address/profile management, and show payment management only when the provider truly supports it. Preserve existing account isolation, logout and deletion behavior.

### F10 — P1/Gate: Rewards is a placeholder experience rather than the required program UI

The reachable Rewards screen draws **two complete circles around the available balance**, not the 270° level-progress arc. It displays Nivel: Pendiente de contrato and several earning/redemption placeholders, including catalog-sharing points and shipping redemption. Required current/next tier, purchase count, percentage, ÉLITE end state and benefit sheet are absent. The balance DTO has no tier/progress fields. Movement-reading components exist, but the main Rewards screen offers no Ver movimientos entry; the mounted Notifications RewardsSection explicitly disables movements.

Evidence: [reachable screen](/Users/alexis/theCode/Monetta/lib/features/rewards/rewards_guide_screen.dart:149), [circle painter](/Users/alexis/theCode/Monetta/lib/features/rewards/rewards_guide_screen.dart:328), [summary DTO](/Users/alexis/theCode/Monetta/lib/features/rewards/rewards_models.dart:8), [movement implementation](/Users/alexis/theCode/Monetta/lib/features/rewards/rewards_section.dart:563), [mounted notifications section](/Users/alexis/theCode/Monetta/lib/features/notifications/notifications_screen.dart:127). Contracts G19–G21, master 011.

Acceptance: agree the authoritative tier/progress/benefit data, then implement the arc, real level/balance and reachable movement history. Pending bonus/cashback rules are an owner/service dependency; do not calculate or invent them in the client. Hide unavailable earning/redemption capabilities instead of publishing design placeholders.

### F11 — P1: notification and wholesale cart states are not represented in navigation

The bottom navigation computes a badge **only for Carrito**. It never reads unread account notifications. It can also replace Cuenta's icon with a profile photo, whereas Correction 5 says to retain the icon when adding its badge. The bar accepts bag quantity but has no authoritative wholesale-eligibility input; its cart icon has no threshold-driven gold/transparent-ring state, confirmed-add droplet or four-second notice.

Evidence: [badge logic](/Users/alexis/theCode/Monetta/lib/features/navigation/monetta_bottom_navigation.dart:402), [account photo replacement](/Users/alexis/theCode/Monetta/lib/features/navigation/monetta_bottom_navigation.dart:518), [cart drawing](/Users/alexis/theCode/Monetta/lib/features/navigation/monetta_bottom_navigation.dart:629). Contracts G14, G14-B; master 010.

Acceptance: feed the account badge from an authorized unread source, preserve the icon, and connect wholesale cart appearance to real eligibility. Hide zero/count-cap as specified/proposed, keep the true total accessible, and animate only after a confirmed new add with reduced-motion fallback.

### F12 — P1: Order Detail lacks both the new shipping progress and the underlying detail data

The screen has state capsules and a vertical event timeline, rather than the horizontal truck → plane → house progress. It explicitly says per-item details are unavailable and sends shoppers to email for breakdowns. Historical address, actual line items/variants and tracking links are absent from the rendered detail; the current summary/customer-order models do not carry those fields. The timeline also returns before adding shipping events when payment is not confirmed, coupling displayed shipment progress to payment status contrary to Correction 5.

Evidence: [state card](/Users/alexis/theCode/Monetta/lib/features/orders/order_detail_screen.dart:148), [missing pieces/breakdown and timeline](/Users/alexis/theCode/Monetta/lib/features/orders/order_detail_screen.dart:253), [payment gate](/Users/alexis/theCode/Monetta/lib/features/orders/order_detail_screen.dart:381), [customer-order DTO](/Users/alexis/theCode/Monetta/lib/data/customer_auth/customer_orders.dart:20), [render](evidence/viewport-order-390.png). Contract G23; G16 also requires authoritative item/delivery details in confirmation.

Acceptance: extend the authorized order read model, render real line items/address/tracking and the three shipping stages independently of payment, and retain distinct partial/cancelled/unknown states. Confirmation must use the same authoritative operation and details.

### F13 — P1: Favorites has no recommendation module

Favorites renders saved products only. **Basado en tus gustos**, two horizontal rows, up to at least 60 unique products when available, progressive loading and editorial fallback are absent. Its empty-state Explorar el catálogo action merely pops the route, which can return to Account rather than opening a catalog.

Evidence: [entire body](/Users/alexis/theCode/Monetta/lib/features/favorites/favorites_screen.dart:92), [render](evidence/viewport-favorites-390.png). Contract G24 and Correction 5.

Acceptance: add the two-row recommendation set with real authorized preferences or an explicitly editorial fallback, preserve product interactions, avoid duplicates and give the empty action a real catalog destination.

### F14 — P1: Contact does not apply the corrected controls and grouping

The hero is overlaid, but it uses legacy artwork and reconstructed lettering. The main action is a gray WhatsApp row plus a separate +52 number, not **Enviar Whatsapp al 826 106 6868** as the single-line button beside a free green WhatsApp icon. The **Únete / A nuestros grupos de emprendedores** heading is missing; the three group rows follow immediately. Social icons use the older gold assets. Existing link handling opens external destinations without automatically sending or joining, which aligns with the interaction requirement.

Evidence: [channel copy](/Users/alexis/theCode/Monetta/lib/features/contact/contact_screen.dart:47), [composition](/Users/alexis/theCode/Monetta/lib/features/contact/contact_screen.dart:172), [comparison](evidence/contact-comparison.jpg). Contracts G38/G40; master 061/064.

Acceptance: use B31/its lettering, implement the exact CTA and left-aligned group introduction, keep the three official group destinations and approved social presentation. Existing configured links require owner validation; their presence in code does not prove the invitations remain valid.

### F15 — P1: Wholesale compresses/stacks the three steps and omits the requested community block

At ordinary mobile size the three cards are squeezed into narrow columns. At enlarged text, the code switches to **one column**, explicitly contradicting the requested single horizontally scrollable row. The page continues into older bags/perfumes editorial banners rather than the specified Comienza a vender community section with Group 1/2. Recommendations are capped at six rather than the common 40 where available. Hero text already overlays the image, but artwork/lettering and reflow still need migration.

Evidence: [step layout](/Users/alexis/theCode/Monetta/lib/features/wholesale/wholesale_screen.dart:106), [continuation and six-product cap](/Users/alexis/theCode/Monetta/lib/features/wholesale/wholesale_screen.dart:189), [comparison](evidence/wholesale-comparison.jpg), [320 px / 200% render](evidence/viewport-wholesale-320-2x.png). Contract G13; master 024/063.

Acceptance: retain readable card widths in one horizontally scrollable row, restore community/buttons/benefits/help, complete the real recommendation set and common end-of-page sections. The received $800/20-day text does not itself authorize operational reservation rules.

### F16 — P1: reflow needs visual review, even where layout checks pass

At **320 px and 200% text**, the Contact hero breaks words into tiny fragments and scales the text down to fit a fixed photograph area. Wholesale likewise shrinks its hero and stacks the steps. `GuideHero` uses a fixed height plus `FittedBox.scaleDown`; this avoids an overflow exception by undoing the user's enlarged reading size. Wider Home renders also retain the mobile-oriented layout/navigation under the default host context; the 1440 first viewport is not the supplied desktop composition. Actual platform layout context must be checked before choosing the final wide navigation pattern.

Evidence: [Contact at 320 / 200%](evidence/viewport-contact-320-2x.png), [Wholesale at 320 / 200%](evidence/viewport-wholesale-320-2x.png), [1440 Home probe](evidence/viewport-home-1440-1x.png), [fixed-height and fitted hero](/Users/alexis/theCode/Monetta/lib/features/boutique/guide_art.dart:479), [host-driven scaffold](/Users/alexis/theCode/Monetta/lib/features/navigation/adaptive_storefront_scaffold.dart:37). Master 065–070; all contracts' 320/768/1440 and enlarged-text acceptance.

Acceptance: let text and hero composition grow/reflow, preserve reading size and photo proportions, retain required component scrolling, and review full scrolled flows, focus and keyboard with actual host geometry. Passing the render probes only establishes that those frames did not throw layout exceptions.

### F17 — Gate: hosted authentication, shipping eligibility and live commerce remain unverified

`openAccount` immediately launches hosted Shopify login for a guest. There is no local v4.1 access screen with the corrected **Seguir como invitado** label. This is a flow/presentation gap, but it does **not** imply that new native Google/Apple implementations should be invented: the delivery leaves the account/provider modality pending. The app already has buyer-identity/cart reconciliation and real checkout handoff. What is not established here is that the configured checkout recognizes the authenticated identity and returns account-eligible free shipping, while guests receive an actual address-based rate, or that returning/cancelling preserves the complete journey.

Evidence: [hosted account entry](/Users/alexis/theCode/Monetta/lib/features/account/account_screen.dart:74), [guest-cart adoption](/Users/alexis/theCode/Monetta/lib/data/shopify/cart/cart_repository.dart:128), [checkout reconciliation](/Users/alexis/theCode/Monetta/lib/app/shopify_checkout_coordinator.dart:85), [buyer identity mapping](/Users/alexis/theCode/Monetta/lib/data/shopify/cart/storefront_cart_api.dart:188). Contracts G15/G15-A/G17/G17-A/G32/G39.

Acceptance: agree the supported access presentation and providers, then verify guest and authenticated checkout, actual shipping quotes, sign-out/recalculation, cancellation, decline/unknown payment and confirmation with authorized test services. Treat missing service proof separately from confirmed visual defects. Do not hardcode free shipping, discounts, balances or payment success.

## Coverage of all 50 contracts

The [contract matrix](contract-matrix.csv) is also available as CSV. **Partial** means a baseline exists but the listed requirement is incomplete. **Core present** means relevant source/tests exist, not that every acceptance criterion or live service has passed. **Missing** identifies a required surface/module absent from the reviewed reachable flow. **Provider gate** requires service/owner resolution. Shared visual and accessibility findings F01/F16 still apply to every row.

| Contract | Screen/flow | Assessment | Evidence/follow-up |
|---|---|---|---|
| G01 | Home | Partial | F01–F03; Home renders |
| G01-A | Featured new collection | Missing required composition | F02; four-card grid instead of selected product/40-item rail |
| G01-B | Most wanted / For you / Wholesale | Partial; For you missing | F02 |
| G02 | Sidebar | Partial | F04/F09/F11 |
| G03 | Categories | Partial; family tree missing | F04 |
| G04 | All brands | Missing required directory/entry | F04 |
| G05 | Collection/catalog | Partial | F05/F06 |
| G06 | Global search | Core present; UI contract incomplete | Search/count tests; F05/F06 |
| G07 | Filters | Partial | F05 |
| G07-A | New/offers/availability | Partial; new/offers absent | F05; business date gate |
| G08 | Sort | Partial | F05; oldest missing |
| G05-A | Brand collection | Partial | F01/F05/F06 |
| G13 | Wholesale | Partial | F15/F03/F16 |
| G09 | Quick view | Partial | F06/F07; selection/add tests |
| G10 | PDP | Partial | F07/F08 |
| G10-A | PDP details/recommendations | Partial | F07; three required sets incomplete |
| G11 | Zoom | Partial | F07; pinch exists, explicit controls missing |
| G12 | Restock request | Partial; request form missing | F08/F06 |
| G14 | Cart | Core present; required UI states incomplete | F11/F17; cart-summary tests |
| G14-A | Cart edits/recovery | Core present; full contract recheck needed | Quantity/recovery source; cart tests; no live ambiguous mutation exercised |
| G14-B | Wholesale gold cart state | Missing | F11 |
| G14-C | Authoritative summary | Core present; eligibility unverified | Shopify-summary tests; F17 |
| G15 | Checkout/payment | Provider gate | Checkout-return tests; F17 |
| G15-A | Address/delivery in checkout | Provider gate | Hosted checkout; F09/F17 |
| G16 | Order confirmation | Partial | F12; authoritative item/delivery detail incomplete; no live payment |
| G17 | Access/registration | Provider gate; presentation gap | F17; no local guest label |
| G17-A | Email/verification | Provider gate | Hosted provider; F17; real OTP not exercised |
| G18 | Account | Partial | F09/F10/F11 |
| G19 | Rewards | Partial | F10 |
| G20 | Tier benefits | Missing | F10; tier/benefit data gate |
| G21 | Balance/movements | Partial; normal entry missing | F10; existing components not exposed by Rewards screen |
| G22 | Order history | Core present | History/filter/status tests; F01/F12 for presentation/detail |
| G23 | Order detail | Partial | F12 |
| G24 | Favorites | Partial; recommendations missing | F13 |
| G25 | Notifications | Core present; presentation incomplete | Inbox/route tests; F11 for account badge |
| G26 | Profile | Core present for name/photo | Profile editor/account tests; provider-supported fields still need validation |
| G27 | Addresses | Missing account management | F09; informational sheet only |
| G28 | Payment methods | Unsupported management exposed as info | F09; conditional provider gate |
| G29 | Preferences | Core present for local interests | Existing PersonalizationScreen; no blanket consent/provider claim |
| G30 | Help/policies | Partial | F03/F09; Contact substitutes for required help destinations |
| G30-A | FAQ/policy reading | Missing required in-app CMS reading flow | F03/F09; privacy external link exists |
| G31 | Layers/return | Core present; incomplete audit | Dialogs/navigation exist; F07; focus/keyboard/return not comprehensively exercised |
| G32 | Failed/cancelled/expired login | Core error handling; provider gate | Hosted login/errors and account tests; F17; designed recovery surface absent locally |
| G33 | Unavailable content/retired links | Partial; acceptance unverified | Missing-product/external-link fallbacks exist; all route states not exercised |
| G34 | App notification permission | Partial | Explicit system-permission request exists; current notice differs from Tus avisos / Ahora no surface |
| G35 | Real options/feed add | Partial | Variant/add tests pass; F02/F06 for missing For you feed and card selection |
| G37 | Recover search/filter results | Core present; controls incomplete | Search/count/collection tests; F05 |
| G38 | Help/contact/external links | Partial | F03/F14; launcher-failure test passes |
| G39 | Guest purchase/shipping/login | Provider gate; UI gap | F17; identity/rates/return need live verification |
| G40 | Contact | Partial | F14/F16 |

## Validation and limits

**239 checks passed in the final runs**:

- **28** existing asset/render/contact checks: [capture-tests.log](evidence/capture-tests.log).
- **201** existing targeted checks covering product cards, collection filters/search, variant selection/add, cart summary/checkout return, account, orders, favorites, notifications, Rewards, Wholesale and compact/iOS navigation: [behavior-tests.log](evidence/behavior-tests.log).
- **10** audit render probes: Home at 320/200%, 390, 768 and 1440; Contact/Wholesale at 320/200%; saved Favorites, Order Detail, a forced sold-out fixture and iOS Home: [render-probes.log](evidence/render-probes.log). Reproducible fixture: [render_probes_test.dart](render_probes_test.dart).

These are automated local checks and rendered Flutter widgets, not a production/device certification. Render checks assert no exception for the sampled frame; they do not certify text readability, full-page reflow or design similarity. No live checkout, payment, push delivery, Google/Apple/OTP login or authenticated customer data was exercised. No fake catalog imagery, balance or sample name from a render was treated as production evidence. A universal compliance percentage would overstate this coverage.

The current tests contain assumptions from older requirements (for example, a four-card new-collection grid, combined filter/sort sheets and legacy Rewards placeholders). Passing those tests therefore cannot be used as v4.1 design approval. Add contract-based acceptance cases as each finding is resolved; preserve the existing commerce tests.

## Suggested implementation order

1. **Shared system:** wire v4.1 assets, UI type roles, Glass controls, card variant identity, hearts and exhausted labels (F01/F06).
2. **Discovery:** correct navigation/taxonomy, Home composition and destinations, collection controls, Favorites recommendations (F02/F04/F05/F13).
3. **Account and service contracts:** resolve tier/progress, addresses/payment-management support, order-detail data, auth/shipping and restock capabilities; implement the corresponding UI (F08–F12/F17).
4. **Editorial completion:** registration/footer/policies, product continuation, Contact and Wholesale (F03/F07/F14/F15).
5. **Acceptance:** rerender all affected contracts, then validate complete guest/authenticated journeys on iOS/Android and wide layouts with 320 px, enlarged text, keyboard/focus, reduced motion and real test services (F16/F17).

Design approval should be based on those concrete screens and journeys. The owner still needs to resolve the delivery's pending bindings, provider choices, commercial date for Nuevo and Rewards/reservation rules; these are not permission to invent product behavior.
