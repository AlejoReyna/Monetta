# Monetta for iPhone Duo: design and launch plan

Prepared 27 October 2026. Status: researched proposal, ready for implementation planning. This document does not certify the current build as Duo-ready.

## Product decision

Build **one Monetta shopping experience that expands into a boutique on the inner display**. Keep the existing warm identity and Flutter commerce foundation. Make choosing a product easier through a persistent browsing context, a proportionate gallery, readable purchase details, and continuity when the shopper opens or closes the phone.

The launch should have three visible strengths:

1. **Browse beside the product.** On a sufficiently wide inner display, choosing a piece opens its details beside the collection; filters and the collection position remain available.
2. **See the piece and its purchase details together.** A direct product page uses gallery and details columns when space permits. A seated layout moves the gallery above the fold and purchase controls below it.
3. **Continue without restarting.** Folding, rotating, opening the keyboard, or entering Split View preserves the selected piece, variant, images, filters, cart, and current task.

The product principle is “more room to choose.” The larger display should improve decisions, rather than simply increase the size of every component.

Companion: [proposed layout board](design/iphone-duo/monetta-duo-design-board.svg). It is a concept illustration; device geometry, system chrome, product names, and prices are illustrative. It is not an App Store screenshot or evidence of implemented behavior.

## 1. What was reviewed

The review covers the current working tree, including its existing uncommitted changes. It uses the Flutter sources, design tokens, iOS configuration, existing reference images, and read-only navigation through the installed Monetta Staging app in Device Hub on an iPad Pro 11-inch simulator. The installed build was not rebuilt for this review, so observations from it are supporting examples, not proof that it matches every current source change.

Existing product goldens include placeholders because network product images are deliberately omitted by the harness. Those empty images are not treated as a production defect. Some older goldens also lack usable font rendering; visual conclusions rely primarily on the current token/source contract and the installed staging sample.

No app implementation, dependency upgrade, store submission, or production change is included in this planning work. Existing user changes are preserved. No Duo device runtime or physical Duo was exercised, and no app tests were run for this document-only change.

### Current strengths and specific gaps

| Area | Evidence in this repository | Assessment and design response |
|---|---|---|
| Brand | `design-system/monetta.tokens.json`; `lib/features/boutique/boutique_tokens.dart` | Strong, coherent foundation: warm ivory, brown actions, restrained gold, Playfair Display for editorial roles and Inter for controls. Preserve it. |
| Product photography | `lib/features/product/product_screen.dart:526`; `lib/app/media/monetta_image.dart` | Contained photography protects handles and silhouettes. Keep that behavior. The product gallery is currently a full-width 4:5 block in one long list, so it becomes disproportionately tall on wide screens. In the installed iPad sample, the first viewport was almost entirely the product photograph, with name and purchase information below it. |
| Product detail | `lib/features/product/product_screen.dart:263` | One vertical page with no gallery/detail split. Extract reusable content and purchase state before creating multiple presentations. |
| Main navigation | `lib/features/navigation/monetta_bottom_navigation.dart:43`; `lib/features/home/home_screen.dart:311` | A custom horizontal Flutter bar, with content capped at 480 logical pixels. It will not acquire UIKit’s vertical layout merely by compiling with a newer SDK. Several destinations are pushed routes; create a shared destination and history model before adapting their presentation. |
| Navigation safe areas | `lib/features/navigation/monetta_bottom_navigation.dart:66` | The current bar deliberately omits a bottom safe-area inset. Reassess this contract for every edge, including vertical controls and the home indicator. This is a source risk to test, not a claimed observed overlap on Duo. |
| Purchase action | `lib/features/product/purchase_dock.dart` | Already has a minimum 48-pixel action, a real safe-area wrapper, and pending-state protection. Preserve those strengths, but scope the dock to the detail region when expanded. |
| Catalog grid | `lib/features/catalog/product_card.dart:232`; `lib/features/catalog/product_tile.dart:755` | The grid already measures local width and gives text extra height. Reuse it. Current column thresholds are 340/720/1060, while generated token bands are 768/1024/1280; consolidate the contracts so panes do not choose inconsistent density. |
| Cart | `lib/features/checkout/checkout_screen.dart:310` | Already has a two-column layout at 860 logical pixels. Adapt this existing work to local pane width, shorter heights, keyboard, and fold regions. A blanket cart rewrite is unnecessary. |
| Text enlargement | `lib/app/text_scale_policy.dart:6`; `lib/main.dart:1049` | The root scaler caps body growth at 1.5× and headline growth at 1.2×, with a 24-pixel body ceiling. Remove the global restriction and solve overflow through reflow, taller rows, and fewer columns. |
| Sharing | `lib/features/product/product_screen.dart:126` | Sharing passes text and a subject but no source rectangle. Add a valid, current source anchor for large or changing presentation regions; test after a fold and rotation. Include the canonical product link when available. |
| Native checkout | `ios/Runner/ShopifyCheckoutBridge.swift` | Checkout Sheet Kit is already native; Podfile.lock pins 3.8.1. Keep its ownership of payment. Verify its presentation and return behavior on Duo rather than building a custom payment layout. |
| Session and catalog | `lib/app/catalog_store.dart`; `lib/app/cart_controller.dart`; `lib/data/local/`; `lib/reco/` | Existing local cache, saved products, recommendation logic, and cart coordination are useful foundations. Resizing must not recreate these services or repeat mutations. |
| Product facts | `lib/domain/product.dart`; `lib/data/normalize/facets.dart` | Normalized brand, category, silhouette, colors, price, and stock are available. Structured dimensions and material are not explicit fields in the reviewed model. An advanced comparison feature therefore needs a data contract first. |
| iOS host | `ios/Runner/Info.plist`; `ios/Runner/SceneDelegate.swift` | Scene lifecycle exists; phone portrait and both landscape orientations are declared; device family is iPhone and iPad. Multiple scenes are disabled. Duo does not by itself require a separate app or a multiwindow implementation. |
| Validation | `test/features/product/product_layout_responsive_test.dart`; `test/goldens/ui04_typography_goldens_test.dart` | Existing static width/text matrices and phone reference images are useful. They do not establish continuity during live resizing, asymmetric side insets, or active fold avoidance. |

### Local readiness observed

- Repository toolchain: Flutter **3.44.8**, Dart **3.12.2**, as recorded in `.fvmrc` and the README; the resolved Flutter package also points to 3.44.8.
- Installed compiler: **Xcode 27.1**, iPhoneOS SDK **27.1**.
- `simctl list runtimes`: only **iOS 27.0** is installed. The Duo device type exists, but there is no configured Duo simulator in the available device list.
- First setup task: install the iOS 27.1 runtime and create a Duo simulator in Device Hub, then build the actual app with its intended release configuration. Compiler availability alone does not establish runtime readiness.

## 2. Apple guidance and the launch label

Keep three things separate: App Store asset requirements, Apple’s interface guidance, and Monetta’s product choices. A comparison tool, Pencil support, or a seated shopping layout is not a documented prerequisite for the Duo badge.

### The published launch path

Apple’s preparation page distinguishes older SDK compatibility layouts from the fuller display behavior available with iOS 27.1. Its published badge path is to submit iPhone Duo screenshots in App Store Connect. A featuring nomination is a separate editorial request. Build against iOS 27.1 or later, validate resizing, then upload genuine device captures. This does not require raising Monetta’s minimum deployment version to iOS 27.1; new APIs need availability guards. [Apple: prepare for iPhone Duo](https://developer.apple.com/iphone-duo/prepare/)

The developer resources illustrate the label as **“Made for iPhone Duo.”** Keep the app named Monetta and let App Store Connect display its supported badge. Screenshot upload is the published mechanism; this plan is not a promise of review approval or editorial placement. [Apple: get ready for iPhone Duo](https://developer.apple.com/iphone-duo/)

As checked on 27 October 2026, accepted Duo screenshot sizes are:

| Display | Portrait pixels | Landscape pixels |
|---|---:|---:|
| Outer | 1398 × 2034 | 2034 × 1398 |
| Inner | 2007 × 2853 | 2853 × 2007 |

Apple accepts JPEG/JPG/PNG without alpha and permits up to ten images per device size. Its current page says Duo screenshots become required in April 2027 for apps using iOS 27.1 or later. For Monetta’s badge launch, provide them now, along with the usual required iPhone screenshots and iPad assets while iPad remains supported. Recheck specifications at submission. These are asset dimensions, not layout breakpoints. [Apple: screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)

### Interface guidance translated into implementation work

| Apple guidance | Monetta implementation | Completion evidence |
|---|---|---|
| Use resizable layouts and preserve the experience across poses. | Share route and shopping state across compact and expanded presentations. | Open and close the device during a real shopping task without losing context. |
| Respect safe areas and reserved regions. | Measure the current content region; move actionable groups away from active fold/camera regions. | Geometry overlay plus screenshots showing reachable controls. |
| Follow the system’s bar axis. | Side controls on the outer display and inner landscape; horizontal bars on inner portrait as directed by the host. | Capture each configuration, including limited height and overflow. |
| Keep the same functionality and hierarchy. | Every shopping action remains reachable in compact, regular, and Split View layouts. | Same task passes in each presentation. |

These are design expectations, not a separate public feature certification checklist. [Apple HIG: designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)

Native navigation containers manage vertical bars and overflow; drawing a custom `UITabBar` or using Flutter’s Material bar does not gain that behavior automatically. Give toolbar actions both a symbol and an accessible title. Text-bearing controls such as search, variants, and the purchase action belong with their content rather than being squeezed into a narrow rail. [Apple: Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/)

For partial folds, move related interactive elements together into usable regions. Continuous lists can remain scrollable through the fold; buttons and transient controls need deliberate placement. Use the platform’s division and occlusion regions instead of inventing a fixed hinge gap. [Apple: adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/)

Accessibility remains part of the design. Support substantial text enlargement, VoiceOver, reduced motion, sufficient contrast, and reachable controls. Monetta will retain a 48×48 logical-pixel minimum target as its own stricter product standard; do not describe 48 as an Apple-mandated number. [Apple HIG: accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

## 3. Specific design: Monetta, unfolded

### Identity and visual rules

| Role | Proposed treatment |
|---|---|
| Canvas | Existing warm ivory `#FBF8F2`; use the existing dark semantic palette in dark mode. |
| Navigation ground | Existing `#F7F3EC`, or native material where the system owns the bar. Product photography stays on a quiet opaque ground. |
| Main action | Existing brown `#745237`, white label, 52-pixel minimum height; grow when text wraps. One primary purchase action per visible product. |
| Text | Existing ink `#211B16`; secondary ink `#73665D`. |
| Gold | Existing `#C5A052` for the logo and decoration. Keep readable labels in the appropriate ink or accent-text token. |
| Typography | Playfair Display: editorial headings and product names. Inter: prices, navigation, input, labels, and body. Start body at 17, secondary at 15, product title at 26–30, price at 20; respect the user’s system scaling. |
| Spacing | Reuse the 4/8/12/16/24/32 scale. Compact content margins 16–20; roomy pane margins 24. Gaps are added to system geometry, not substitutes for it. |
| Shape | Existing 12-pixel cards/controls and 20-pixel sheet radius where Flutter owns the surface. Native sheets keep their system geometry. Avoid extra nested panels around every content group. |
| Photography | Contain packshots, retain the full handle and strap, and use focal-point-aware crops only for editorial photography. Never stretch a bag to fill a pane. |

Computed from the existing solid light colors: ink/canvas is approximately **16.07:1**, muted ink/canvas **5.23:1**, and white/brown **6.99:1**. Gold/canvas is only **2.32:1**, supporting its decorative role. These calculations are not a full screen audit: tinted, transparent, image-backed, disabled, selected, and dark states need their own checks.

### Navigation contract

Retain four destinations: **Inicio, Catálogo, Carrito, Cuenta**. Standardize the current “Home / Inicio” and “Categorías / Catálogo” variations. Keep saved products reachable from the existing navigation/account paths and contextual save action; do not add a fifth destination just for Duo.

For vertical presentation, place Back/Close first, contextual search/actions next, secondary actions in overflow, and the four destinations toward the lower end. Preserve the cart badge. Use the host’s edge and occupancy information; do not hardcode “right rail on every wide window,” because Split View can change the usable edge.

Inner portrait returns to horizontal bars. On all configurations, selection has a shape/weight or other non-color indicator, semantic selected state, and an accessible label. The long “Agregar al carrito” button remains a content action with room for its label.

### Layout rules

All widths below are **proposed content thresholds in Flutter logical pixels after outer safe areas and navigation occupancy**, not device detection rules. Measure pane internals with `LayoutBuilder`. OS size classes and reserved regions add context; “iPhone” must not imply compact width. Revise thresholds using the actual Duo runtime before freezing them.

| Available content region | Catalog | Direct product page | Cart |
|---|---|---|---|
| Less than 360 wide | One readable product column. | Stacked gallery and details. | One list; summary in flow. |
| 360–699 wide | Two columns when each image/text cell fits. | Stacked; gallery height capped to about 55% of usable height so identity and price appear sooner. | One list; compact total/action can remain visible if height allows. |
| 700–919 wide, usable height at least 480 | Three columns with no selection; choosing a piece opens a browse/detail arrangement with minimum panes about 320 and 340, plus a 24 gap. The narrow browse pane may use one column. | Two columns, roughly 52/48, with gallery and details each independently usable. | Lines and summary side by side only if both meet their content minimums. |
| At least 920 wide | Up to four product columns; selected detail beside browsing, about 44/56. | Gallery/details about 56/44; keep running copy within 45–65 characters per line. | About 60/40 lines and summary. |
| Active division region | Split at the platform-provided region, adapting pane ratios as needed. | Keep the product/control groups within suitable regions. | Put the summary action wholly in one region. |
| Very short region or large accessibility text | Reduce columns and chrome first. Retain scrolling and overflow actions. | Prefer a single readable flow if two panes stop fitting. | Summary scrolls in flow if pinning would obscure the task. |

Do not stack two safe-area paddings around a pane already inset by the host. Do not subtract a nominal rail width when the native host has already removed it. Define this ownership once in the shell.

### Screen-by-screen experience

| Screen | Outer display / compact window | Inner display / roomy window | Partial fold and continuity |
|---|---|---|---|
| Inicio | Short editorial hero, search, novedades, then existing styles and collections. | A wider editorial composition with a controlled image height and readable copy, followed by denser product rails. Preserve Shopify’s configured section order. | Reflow the hero; keep the current section visible and preserve the scroll anchor. Do not introduce a different home hierarchy per pose. |
| Catálogo, collection, brand | Filters and sort remain near the result count. Open a product as the next detail level. | Collection and selected product coexist. Visually identify the selected card; opening its full gallery remains explicit. | Keep query, facets, sort, selected product, and source position. On collapse, selected detail becomes the active page; Back returns to the same result anchor. |
| Search | Field stays associated with results and keyboard; suggestions remain reachable. | Results and selected detail can coexist when width permits. | Preserve text, focus intent, keyboard task, and pending search generation. Do not restart the query merely because dimensions changed. |
| Product, direct/deep link | Contained gallery, name, price, variants, clear stock status, then details. Purchase action remains reachable. | Gallery beside a detail column. The primary action is attached to the detail pane, not the entire display. | Preserve product and variant by stable ID, current image, zoom where feasible, open accordions, and add-to-cart progress. |
| Product, seated | Same functionality remains reachable if the usable window is compact. | Gallery in the upper region; variant and purchase controls in the lower region, using actual division bounds. | Enter this arrangement only when geometry supports it. Avoid a new shopping “mode” or angle-specific feature gate. |
| Guardados | Existing saved grid; clear empty state. | Larger grid plus selected detail. | Saved state remains shared. Comparison is a later, optional enhancement. |
| Carrito | Lines and variants first; totals and checkout follow. | Reuse existing two-column logic with a locally measured summary. | Preserve pending quantity edits and remote cart state. Never recreate the cart during a fold. |
| Cuenta and pedidos | List to detail navigation. | List/detail when useful; otherwise center the readable account content. | Keep auth session and order selection. Rewards panels do not become oversized banners. |
| Filters, quick view, settings | Sheets respect keyboard, safe area, and a reachable Close. | Contextual panel or appropriately bounded sheet. | Move to a suitable usable region; keep form selections and errors. A centered Flutter modal is not assumed to avoid the hinge automatically. |
| Checkout and OAuth | Present through their existing native integrations. | Let the SDK/browser own the form and payment UI. | Verify folding during load, login, payment selection, cancellation, and return without losing the transaction context. |

### The signature task to design and review first

“Find a brown crossbody, inspect it, choose a variant, and buy it.”

1. On the outer display, search for crossbody and choose a color filter.
2. Open a piece and select its variant.
3. Unfold: the same piece appears beside the original filtered collection, with the source position preserved.
4. Inspect another image or another piece without losing the filter context.
5. Set the device down partially folded: gallery and controls stay comfortably readable in their respective regions.
6. Add once, fold closed, open the cart, and continue to native checkout.
7. Cancel checkout and return to the same valid cart, or complete a sandbox checkout and reconcile the order exactly once.

This task is the first design prototype and the final launch demonstration. Do not reserve any step exclusively for the inner display.

### Motion and feedback

Let the system own display-transition motion. Use short content crossfades, around 160–220 ms, only where they clarify a pane change. Avoid an additional simulated folding animation or replaying startup reveals after resize. Reuse the existing reduced-motion policy in `lib/app/motion.dart` and provide a near-instant alternative.

Keep images stable while higher-resolution assets arrive. Match the current hero/media cache strategy to pane width and display scale; preload only adjacent gallery images. Cart confirmation uses a restrained success response and an explicit “Ver carrito” path; do not interrupt browsing with a full-screen celebration.

## 4. Implementation architecture and its first decision gate

### Retain Flutter; add platform geometry deliberately

Flutter’s official `MediaQueryData.displayFeatures` documentation currently says that the list is populated **only on Android**. Local constraints and safe areas can support ordinary resizing, but they do not prove iOS hinge awareness. Use a small native bridge unless the first spike verifies an equivalent supported path in the pinned engine. Do not add an unverified third-party foldable dependency to the release plan. [Flutter: displayFeatures](https://api.flutter.dev/flutter/widgets/MediaQueryData/displayFeatures.html)

Use `LayoutBuilder` for each pane and `MediaQuery.sizeOf` for the app window. Keep data/controllers outside layout branches. That matches Flutter’s documented separation of shared data, measurement, and presentation. [Flutter: adaptive apps](https://docs.flutter.dev/ui/adaptive-responsive/general)

The intended structure is:

```text
Existing catalog, account, cart, notification and checkout controllers
                            |
                   ShoppingSessionState
          destination / history / selection / anchors
                            |
                   AdaptiveStorefrontShell
                  /                    \
      SystemLayoutContext          Reusable screen content
      current window geometry      browse / gallery / details / cart
      safe edges and regions
                  |
         iOS 27.1 host adapter
         availability guarded
```

Proposed files and ownership:

| Work | Suggested location | Owner |
|---|---|---|
| Geometry adapter and channel lifecycle | `ios/Runner/DuoLayoutBridge.swift` plus host integration | iOS engineer |
| Immutable geometry snapshot, capability flags, fallback | `lib/platform/apple_layout_context.dart` | Flutter + iOS |
| Shared destination, route, selection, and restoration model | `lib/app/shopping_session_controller.dart` | Flutter |
| Compact/expanded shell and navigation renderer | `lib/features/navigation/adaptive_storefront_shell.dart` | Flutter |
| Browse/detail coordination | `lib/features/catalog/browse_detail_layout.dart` | Flutter |
| Extract product state/content from the existing screen | `lib/features/product/product_screen.dart` and focused new components | Flutter |
| Pane-aware dock and modal presenter | Existing purchase dock, quick view, and shared presentation helpers | Flutter + iOS |
| Threshold source of truth | `design-system/monetta.tokens.json`, then regenerate outputs | Design + Flutter |

These are proposed file paths, not files already implemented by this work.

### Geometry contract

Publish a coherent snapshot of the current host view bounds, safe insets, available bar edge/occupied area, horizontal and vertical size classes, active and inactive division regions, and active occlusion regions. Apple exposes view-relative reserved regions and a vertical-bar trait; use those APIs rather than raw hinge-angle guesses. [Apple: preparing your app](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)

The local iOS 27.1 UIKit headers confirm `UIViewReservedRegion` with a frame, included margins, kind, and active state, plus `UIView` region queries. Treat this as a usable native foundation, not proof that Flutter already forwards the information.

Convert rectangles into the Flutter host view’s coordinate system and verify logical-unit mapping after rotation and resizing. Regions can include their own margins; do not add an invented hinge inset on top. Recompute from layout/safe-area/trait changes, coalesce updates, and ignore stale geometry snapshots. Unsupported systems publish an explicit capability fallback. An empty region list must not be interpreted as proof of a particular physical pose.

### Navigation implementation decision: resolve before screen migration

**Preferred starting approach:** keep one Flutter engine, implement the shared Flutter shell, and reproduce the system’s bar placement and overflow rules using verified host geometry. Retain native sheets for checkout, sharing, and authentication where already available. This is the smaller change to the current app.

The first spike must establish whether the bare Flutter host provides enough bar-axis and occupied-area information. A native trait being available in the SDK does not establish that it is meaningful outside the native containers that produce bars.

If that contract is insufficient, prototype a supported UIKit navigation host and revise the estimate before migrating screens. Native `UINavigationController` / `UITabBarController` integration is the route to automatic system bar behavior, but it needs an explicit Flutter view/controller ownership and engine strategy. Do not assume that one engine can display several independently attached Flutter view controllers, or silently multiply engines, sessions, and cart stores. The spike must show ownership, lifecycle, back navigation, and modal presentation working together.

**Exit gate:** a recorded demo of a selected product surviving outer → inner → portrait → Split View, with correct controls and one running session. If the gate fails, resolve the host architecture before investing in the visual rollout. This is the main schedule uncertainty.

### Continuity contract

Store state above compact/expanded layouts:

- Destination and navigation history, including the collection that opened a piece.
- Selected product and variant **IDs**, not only list indices that can change during live sync.
- Query, facets, sort, selected result, and per-list scroll anchor by item ID plus relative offset.
- Current gallery image and compatible zoom state; expanded details and scroll position.
- Form drafts, errors, focus intent, and active sheet task.
- Cart mutation progress, checkout session, authentication flow, and cancellation/return state.

Use one product presentation state when the same piece moves between a page and a pane. Layout changes must not duplicate `Hero` tags, start a second dwell session, repeat analytics impressions, recreate an OAuth request, or submit an add/quantity mutation again. Existing pending-action protection remains authoritative.

The current checkout presenter selects the first key window across connected scenes. Scope future presentation to the initiating scene/host as part of the geometry work. Keep `UIApplicationSupportsMultipleScenes` disabled until a separate multiwindow feature is designed; single-scene display transitions still need testing.

## 5. Prioritized delivery backlog

“Launch” below means Monetta’s intended quality bar. It does not imply that Apple explicitly mandates each product feature to award the badge.

| ID | Priority | Deliverable | Acceptance criterion | Effort estimate |
|---|---|---|---|---:|
| DUO-01 | P0 | Runtime setup, current build baseline, geometry/navigation spike | Working Duo runtime; native-to-Flutter bounds, insets, regions and bar context recorded; architecture gate passed. | 3–5 engineering days |
| DUO-02 | P0 | Shared session and adaptive shell | Four stable destinations; independent history/anchors; side and horizontal controls; no duplicated state after resize. | 4–6 days |
| DUO-03 | P0 | Product content extraction and expanded/seated layouts | Gallery and purchase details proportionate; variant/image retained; one reachable primary action outside active fold region. | 4–6 days |
| DUO-04 | P0 | Catalog/search/collection browse-detail | Filters, count, sort and selected piece remain consistent; collapse/back restores the source anchor. | 4–6 days |
| DUO-05 | P0 | Presentation and checkout adaptation | Share anchoring; filters/quick view placement; OAuth and checkout cancellation/completion survive transitions without duplicate actions. | 3–4 days |
| DUO-06 | P0 | Text, focus, cart and account fit | Remove global text cap after responsive fixes; essential content usable at 200% and maximum supported accessibility settings; all edges safe. Reuse cart split layout. | 3–5 days |
| DUO-07 | P0 | Physical-device QA and release assets | Task matrix passes; genuine Duo captures uploaded; matching App Store preview verified. | 3–4 engineering days plus QA |
| DUO-08 | P1 | Two-piece comparison from saved products | Same structured facts and variants shown side by side when roomy and sequentially when compact; available in every pose. | 4–6 days after data contract |
| DUO-09 | P1 | Drag to saved/cart, with explicit buttons as alternatives | Variant selection is explicit; dragging never silently chooses an unavailable/default variant. | 2–4 days |
| DUO-10 | P2 | App Intents, order widgets/Live Activities, richer styling tools | Ship only for a proven customer task with a maintained data lifecycle. | Separate discovery |

Do not make Pencil input, AR try-on, two simultaneously active displays, camera permissions, AI styling, or multiwindow support dependencies for this launch. They do not solve the immediate layout/continuity problem, and the researched badge path does not list them as prerequisites.

### Comparison data gate

For the first optional comparison release, compare reliable existing fields: product photo/name, normalized brand, selected variant, price, stock, color, and silhouette. Reconcile any changing price/stock through the existing source of truth. To add material, dimensions, strap length, or delivery promises, first define Shopify metafields, map/cache them, and audit missing values. Display “No especificado” where appropriate; never derive measurements or material from an image or invented copy.

## 6. Sequence, team, and planning estimate

The P0 backlog totals **24–36 engineering days**. This is a planning estimate, not a measured delivery commitment. Allow **6–8 design days** and **7–10 QA days**, partly concurrent. With a Flutter engineer, an iOS-capable engineer, and part-time design/QA, target **5–7 calendar weeks** after the runtime and architecture gate. With one engineer covering both platforms, allow roughly **7–9 weeks**. A larger native-shell change can add **1–2 weeks** and requires re-estimation after DUO-01.

| Milestone | Sequence | Reviewable output |
|---|---|---|
| M0: feasibility | First 3–5 engineering days | Current-build baseline and geometry/host demo. Freeze implementation architecture. |
| M1: design specification | Start with M0; complete before product migration | Signature-task frames, compact/roomy/short-height/accessibility states, tokens, navigation order and modal behavior. |
| M2: shell and continuity | After M0 | Four destinations with state-preserving reflow. Test pane collapse/back before adding visual polish. |
| M3: shopping experience | After M2; product and browse work can overlap | Product gallery/details, browse-detail, seated purchase layout, cart and native handoffs. |
| M4: release candidate | After M3 | Device QA, accessibility fixes, performance traces, genuine screenshots and review notes. |

Design review should include the shop owner and representative shoppers: ask them to find a piece, change a variant, fold the device mid-task, and recover from a canceled checkout. Watch whether the layout makes the next action obvious, not just whether the screens are attractive.

## 7. Validation and release gates

### Device and configuration coverage

| Dimension | Required coverage for this proposal |
|---|---|
| Displays / poses | Outer, inner landscape, inner portrait, partially folded book, seated; standing/tent use keeps the available outer-screen experience usable without adding a special mode. |
| Window sizes | Actual Duo geometry; both Split View sides; resizable window extremes; 320/360/390/440/600/699/700/768/919/920/1024 logical widths and short heights. Synthetic widths are tests, not assumed device specifications. |
| Geometry | Asymmetric left/right insets, active and inactive division region, active camera occlusion, changing system occupancy; actual runtime plus deterministic geometry fixtures. |
| Accessibility | Default, 200%, and largest supported system text settings; VoiceOver; Bold Text; Increase Contrast; Reduce Motion; Reduce Transparency; hardware keyboard/focus. |
| Content | Long Spanish names, multi-variant and sold-out products, sale prices, missing images/facts, many cart lines, empty/error/offline states. |
| System handoffs | Keyboard on/off, share sheet, OAuth browser, notification/deep link, checkout loading/cancel/completion, background/foreground. |
| Regression | Small conventional iPhone, large iPhone, supported iPad layouts, Android phone and its existing adaptive behavior. |

### Meaningful automated checks

Extend existing layout tests; do not replace their reference goldens without reviewing the change. Add deterministic geometry fixtures and a small number of task-focused integration tests:

1. **Resize during selection:** change constraints and native-region snapshots repeatedly on the same mounted widget. Assert stable product/variant/image/filter IDs and no overflow. Separate pumps into fresh app instances do not test continuity.
2. **Browse/detail collapse:** select a result, collapse, press Back, and assert the same filtered result anchor; expand again without duplicating the detail state.
3. **Mutation in flight:** fold during add-to-cart and a quantity update. Assert exactly one mutation and a valid eventual cart; include a failure/retry case.
4. **Presentation:** an active-region fixture places Close, share anchors, and purchase actions wholly within usable regions. Use intersection checks for important actionable bounds.
5. **Checkout return:** cancel and complete through the supported test path while resizing. Assert one order reconciliation and no second checkout launch.
6. **Accessibility reflow:** unclamped system text, readable labels, semantic selected state, logical focus traversal, and one reachable purchase action.

Run relevant Flutter tests and analyzer for the actual implementation, plus native build/integration checks. Existing golden failure images are pre-existing artifacts; their presence alone is not a test result from this review.

### Human acceptance and performance

- Complete the signature task on a physical Duo and conventional iPhone. Require zero lost selections, duplicate cart additions, blocked controls, or unrecoverable checkout returns in the release scenarios.
- Verify actual fold interaction, touch reach, camera/system occupancy, and modality on hardware. Simulator screenshots cannot establish ergonomics or hinge behavior by themselves.
- In profile/release builds, measure scrolling and resizing against the observed display cadence: at 60 Hz a frame is about 16.7 ms; at 120 Hz about 8.3 ms. Aim for fewer than 1% over-budget frames in the scripted browse/product task and no repeated visible stalls. These are proposed Monetta performance goals, not Apple badge thresholds.
- Run a repeated fold/rotate/background loop and inspect allocations for monotonic growth, repeated image decodes, duplicate listeners, and recreated engines/controllers. Establish the baseline before choosing a memory ceiling.
- Track task completion, product-to-cart conversion, checkout completion, lost-context incidents, and duplicate-mutation incidents. Compare task success across layouts rather than promising an unmeasured conversion increase. Use the existing telemetry consent/data rules; do not log raw queries or customer form content merely to measure Duo support.

## 8. App Store package

Prepare five real capture concepts after implementation:

1. **“Más espacio para descubrir.”** Inner landscape: filtered collection beside a selected product.
2. **“Cada detalle, a tu manera.”** Inner display: gallery and purchase information together.
3. **“Tu próxima favorita, siempre a mano.”** Outer display: the same selected piece and clear action.
4. **“Todo listo para elegir.”** Inner portrait: readable detail layout with its horizontal navigation behavior.
5. **“Tu bolsa, sin perder el ritmo.”** Cart and order summary; include genuine states and accurate prices.

For a short app preview, record the signature task and its continuity rather than a fabricated hinge animation. Keep screenshot families and layouts accurate to the displayed configuration. Do not upload the companion concept board as app evidence.

Supply concise review notes explaining the adaptive navigation, selected-product continuity, and how to reach checkout. Verify the usual working backend, review access, accurate metadata, and privacy/account flows. Monetta sells physical goods, for which Apple’s review guideline 3.1.3(e) allows payment methods other than In-App Purchase. Retain Shopify checkout; Apple Pay availability is a separate merchant/gateway capability to verify, not a Duo-badge requirement. [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

Upload Duo assets and inspect the product-page preview/badge behavior in App Store Connect. Separately nominate the release for featuring, describing its supported poses and actual shopping benefits in Helpful Details. Editorial selection remains Apple’s decision. [Apple: featuring nominations](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/)

## Recommended first implementation ticket

**DUO-01: prove the host geometry and navigation contract in the current Flutter app.** Install the missing runtime, run the existing build on Duo, expose view-relative reserved regions and bar context, and demonstrate one selected product surviving display and window changes. Deliver the geometry log, short recording, and chosen host architecture. This resolves the most consequential unknown before visual implementation begins.
