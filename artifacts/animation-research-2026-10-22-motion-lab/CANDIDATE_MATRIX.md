# Monetta motion candidate matrix

This is design prioritization informed by implementation inspection, not a measured conversion or accessibility score. **Adopt** means suitable for a future implementation; this research authorizes no production edits. Existing behavior can earn a high score even when the recommendation is to preserve it. **Explore** needs evidence before shipping. **Reject** means reject the described motion, retaining its static functional state.

Scores are 1–5, high is favorable: usefulness **U**, brand fit **B**, accessibility **A**, low effort **E**, low performance risk **P**. Weighted total = `3U + 2B + 2A + E + P`, maximum 45. Ties favor direct purchase needs, then predictable interaction. These coarse judgments express priorities; they are not benchmark measurements.

All proposed movement uses `cubic-bezier(.16,1,.3,1)` unless stated. The starting tokens are 180/280/480ms (`storefront-theme/assets/monetta-tokens.css:148`; `lib/app/motion.dart:10`). The app additionally defines 720ms entrances and 18s Ken Burns, uses 260ms/easeOut home scroll (`lib/features/home/home_screen.dart:315`), 920ms theme animation (`lib/app/theme.dart:584`), and other component exceptions. Those timings are **not** universal storefront defaults. No new timing token is proposed. Simulated loading delays are network scenarios, not animation durations.

## Ranked comparison

| Rank / candidate | Classification and precedent | U/B/A/E/P | Total | Decision and reason | Lab |
|---|---|---:|---:|---|---|
| 1. Add confirmation | Refine app + storefront state feedback | 5/5/5/4/5 | 44 | **Adopt:** truthful pending/success/error prevents uncertainty and repeat purchases. | 03 |
| 2. Reversible overlays | Adapt app drawer/sheet; refine storefront lifecycle | 5/5/5/3/4 | 42 | **Adopt:** orientation benefits justify one bounded transition. | 01 |
| 3. Disclosure indicator | Preserve app + storefront native-style disclosure | 4/5/5/5/5 | 42 | **Adopt:** rotate indicator; keep essential body instant. | 05 |
| 4. Variant/gallery changes | Adapt app gallery; refine existing latest-request logic | 5/5/4/3/4 | 40 | **Adopt native navigation/guards; explore crossfade:** preserve selection context; test overlapping images carefully. | 02 |
| 5. Count/quantity acknowledgement | New small cue over existing authoritative state | 4/5/5/3/4 | 39 | **Adopt:** confirmed change gets restrained emphasis; no animated prices. | 03 |
| 6. Saved-product feedback | Refine existing pressed state | 3/5/5/5/5 | 39 | **Adopt:** small local acknowledgement with persistent state. | 04 |
| 7. Header / persistent purchase chrome | Preserve existing implementation | 3/5/5/5/5 | 39 | **Adopt static:** hairline only; persistent mobile purchase remains baseline. | 06 explains baseline |
| 8. Product-card feedback | Adapt app fixed-hit-area lift; refine web feedback parity | 4/4/4/4/4 | 36 | **Adopt restrained:** compare image scale; retain clear focus and fixed targets. | 04 |
| 9. Contextual mobile purchase bar | New opportunity when original action leaves view | 3/4/3/2/4 | 29 | **Explore:** helpful reach, but duplicates action and adds focus/viewport complexity. | 06 |
| 10. Editorial section entrance | App precedent; dormant storefront CSS | 2/4/3/3/4 | 27 | **Explore later:** optional story emphasis; static storefront default. | No |
| 11. Search result/panel entrance | New decorative layer on instant web search states | 2/3/3/4/4 | 26 | **Reject repeated entrance:** competes with typing; keep result changes instant. | 01 search stays instant |
| 12. Skeleton/loading shimmer | Dormant Monetta CSS; active legacy-theme precedent | 2/2/2/4/2 | 20 | **Reject persistent shimmer:** static reservation + text is sufficient. | Static/pending text |
| 13. Cross-document page transition | App native route + separate legacy-theme precedent | 2/3/2/1/2 | 19 | **Defer:** optional enhancement needs a separate compatibility spike. | No |
| 14. Fly-to-cart / celebratory success | Separate legacy theme contains flight animation | 1/2/2/2/2 | 15 | **Reject:** movement travels away from action; no need beyond clear confirmation. | No |
| 15. Automatic product motion / error shake | App cinematic tokens are not purchase justification | 1/1/1/2/1 | 10 | **Reject:** loops, parallax, grid stagger and shaking distract or destabilize. | No |

The six compositions represent five recommended families (overlays, gallery, commerce feedback, card/saved, disclosure) and one explicitly lower-priority exploration. They are not six equal implementation commitments.

## Behavior and implementation matrix

For brevity below, **W** means `storefront-theme/`; **A** means `lib/`. Line references identify the inspected checkout, not a deployed-theme test. Complexity includes integration and verification, not just CSS length.

### 1. Add confirmation

| Dimension | Evaluation |
|---|---|
| Need / precedent | Distinguish accepted input, waiting and confirmed outcome. `A/features/catalog/quick_add_button.dart:41` deduplicates; `A/features/checkout/mini_cart.dart:14` confirms in a sheet. `W/assets/monetta-product.js:364`, `monetta-cart.js:219` already wait for Shopify. |
| Mobile / desktop | Inline stable-width button/status on both; existing confirmation becomes phone sheet or desktop drawer. Lab isolates inline feedback. |
| Trigger / motion | Each explicit add; request starts immediately. Pending text instant; success opacity +4px Y 180ms; no additional success delay. |
| Load / interrupt / repeat | One in-flight add; further activations ignored. Error retains confirmed count, visible retry; unknown outcome asks shopper to inspect cart. Never retry a write automatically. Closing a confirmation does not cancel its transaction. |
| Static / accessibility | Zero movement under reduced/static; preserve simulated wait. `aria-busy`, accessible label, polite truthful result; error static. Keep focus on active control unless an intentional modal opens. |
| Rendering / integration | Transform/opacity are candidates for compositing, not a guarantee. Low complexity: `W/assets/monetta-cart.js:258` and product submit path; preserve mutation queue, checkout locks and server-rendered amounts. |

### 2. Reversible overlays

| Dimension | Evaluation |
|---|---|
| Need / precedent | Establish spatial origin and temporary context. `A/features/navigation/monetta_side_menu.dart:77` Drawer; `A/features/catalog/catalog_browse_screen.dart:236` filter sheet. `W/assets/monetta-core.js:65`, `monetta-components.css:1263` provide modal overlays. |
| Mobile / desktop | Menu enters left. Lab filters enter bottom below 600px; desktop filters enter left in this isolated prototype. Production filters currently enter right at every width (`W/snippets/monetta-listing-layout.liquid:75`); side choice requires integration decision. Search panel stays close to its field. |
| Trigger / motion | Explicit open, each time; panel transform280ms, scrim opacity 180ms together. No staged menu-item entrance. |
| Load / interrupt / repeat | Modal content available immediately. One owner cancels pending frames/closing timer; reversal proceeds from current visual state. Resize must preserve content and focus. |
| Static / accessibility | Instant modal under reduced/static. Native dialog, labelled heading, visible close, Escape/backdrop, focus containment and opener restoration. No moving target requirement. |
| Rendering / integration | Broad dialog support; feature-detect/fallback in production. Medium complexity: replace fixed close-time assumptions and global opener in `W/assets/monetta-core.js:62`; preserve scroll compensation and section lifecycle. No library required. |

### 3. Disclosure indicator

| Dimension | Evaluation |
|---|---|
| Need / precedent | Clarify expanded state without delaying information. `A/features/product/product_screen.dart:815` rotates 180ms, inserts body immediately. `W/assets/monetta-components.css:1689` does the same with native details. |
| Mobile / desktop | Same summary/body on both; long labels wrap without moving the icon hit target. |
| Trigger / motion | Every explicit summary toggle; chevron rotation 180°/180ms. Body 0ms; no height animation or sequencing. |
| Load / interrupt / repeat | Content is already present. Rapid toggles reverse CSS rotation naturally; no animation queue, timers or measuring. |
| Static / accessibility | Instant icon; native `<details>/<summary>` remains keyboard-operable without JS. Keep essential content visible when open; no focus changes. |
| Rendering / integration | Low risk, low complexity; `W/sections/monetta-product.liquid:270`, filter summaries. Transform only; layout change is the disclosure itself, not animated reflow. |

### 4. Variant/gallery changes

| Dimension | Evaluation |
|---|---|
| Need / precedent | Explain image change while retaining size/context. `A/features/product/product_screen.dart:200` scrolls 280ms or jumps reduced. `W/assets/monetta-product.js:22` native gallery, `:160` sequence/abort guard and `:240` radio-focus restoration. |
| Mobile / desktop | Native touch scroll remains; visible thumbnails/buttons and arrows on desktop. Lab compares silhouettes, not real variants or stock. |
| Trigger / motion | Explicit selection only. After decoded image readiness, opacity 280ms in reserved frame. Production price/availability update from confirmed server response, never decorative timer. |
| Load / interrupt / repeat | Keep prior image + truthful caption until ready. New selection invalidates old decode/fade; latest only commits. Failed image retains prior image and retry. No autoplay. |
| Static / accessibility | Swap instant when ready; still report loading/error. Preserve radio/thumbnail focus; accessible selected state and image text. No swipe-only access. |
| Rendering / integration | Medium complexity; two decoded images temporarily increase memory. Scope opacity, avoid unnecessary large layers; reuse existing latest-request guards and section replacement. Native smooth-scroll duration is browser-controlled, not guaranteed280ms. |

### 5. Count and quantity

| Dimension | Evaluation |
|---|---|
| Need / precedent | Locate a confirmed change. `W/assets/monetta-cart.js:50` already updates count/labels; `:403` serializes quantity changes and `:169` restores corresponding focus. |
| Mobile / desktop | Same badge acknowledgement; stable tabular quantity digits. Keep shopping controls large enough on narrow layouts. |
| Trigger / motion | Only confirmed count changes: opacity + scale 1→1.08→1 over 180ms; one cue per final result. Quantity/price text itself stays static. |
| Load / interrupt / repeat | Lab groups rapid local quantity choices to latest value; **production currently serializes/refuses overlap**. Do not copy coalescing without cart-write review. Roll back failed preview; no optimistic confirmed total. |
| Static / accessibility | Instant confirmed number plus status. Preserve focus during server DOM replacement; announce outcome without announcing every intermediate preview. |
| Rendering / integration | Low-medium complexity; animate inner badge, not layout width. `W/assets/monetta-cart.js:50,169,403`; do not derive monetary totals client-side. |

### 6. Saved-product feedback

| Dimension | Evaluation |
|---|---|
| Need / precedent | Confirm a reversible save without opening another surface. `W/assets/monetta-merchandising.js:62` already toggles state/announcement; `monetta-app-alignment.css:39` supplies brown/warm filled-heart state. No custom app pulse claimed. |
| Mobile / desktop | Visible heart on both; fixed 48px lab activation area, no hover dependency. |
| Trigger / motion | Each explicit toggle: inner-icon scale .94→1 and opacity 180ms; state changes immediately. |
| Load / interrupt / repeat | Local lab state only. Repeated toggles cancel previous cue and reflect latest pressed state; future account-sync failures require honest status. |
| Static / accessibility | Persistent fill + `aria-pressed` + updated label/status; instant under reduced/static. Color alone does not convey saved state. |
| Rendering / integration | Low complexity, transform/opacity. Extend existing save handler, retain localStorage fallback behavior in production; no particles, sounds or account-write proposal. |

### 7. Header and persistent purchase chrome

| Dimension | Evaluation |
|---|---|
| Need / precedent | Stable orientation/purchase access. `W/assets/monetta-components.css:5` sticky header/hairline; `:1911` always-visible phone purchase dock. `A/features/home/home_screen.dart:599` contains scroll-dependent chrome, not a universal web mandate. |
| Mobile / desktop | Preserve mobile dock; desktop inline purchase remains static. Existing≤480px-height fallback removes pinned chrome (`W/assets/monetta-pages.css:1053`). |
| Trigger / motion | Header hairline 180ms after scroll; no shrinking, hiding or content translation. No replay beyond border-state changes. |
| Load / interrupt / repeat | No purchase readiness depends on chrome motion. Maintain measured reserved space through resize, text wrapping and keyboard. |
| Static / accessibility | Border switches instantly; persistent focusable purchase. Prevent sticky regions obscuring focus. |
| Rendering / integration | Existing low complexity; border color paints a small area. Preserve `W/assets/monetta-core.js:118` pinned measurements. Reject adding scroll handlers solely for decoration. |

### 8. Product-card feedback

| Dimension | Evaluation |
|---|---|
| Need / precedent | Indicate activation while preserving photography and nested actions. `A/app/card_lift.dart:111` uses 180ms enter/280ms exit, −4px/+1.2%, fixed hit testing. `W/assets/monetta-components.css:965` lifts −2px/shadows 180ms on hover. |
| Mobile / desktop | Touch has explicit tap/press feedback; desktop hover and keyboard focus receive equivalent cue. Image control and separate heart stay reachable. |
| Trigger / motion | Lab image scale 1.015 restrained versus 1.045 expressive, 280ms; pointer/focus exit reverses. Recommend restrained, or keep existing lift after visual review. |
| Load / interrupt / repeat | No navigation delayed by cue. Cancel pressed state on scroll/cancel; never stack animations. Long names wrap in reserved composition. |
| Static / accessibility | Image stays still; focus ring and tap feedback remain. Never transform the action's activation box. |
| Rendering / integration | Low-medium complexity in `W/snippets/monetta-card.liquid:47`; shadow animation paints, image layers consume memory. Do not apply permanent `will-change` to entire grids. |

### 9. Contextual mobile purchase bar — explore

| Dimension | Evaluation |
|---|---|
| Need / precedent | Restore reach only after original purchase action passes above viewport. No matching current behavior: production dock is persistent (candidate7). |
| Mobile / desktop | Lab uses a constrained phone scroll frame; desktop column remains static. This is not a simulated device test. |
| Trigger / motion | IntersectionObserver threshold, not continuous scroll handler; opacity +12px Y 180ms on entry. No replay while remaining beyond threshold. |
| Load / interrupt / repeat | Reserve final content space. Never hide while bar contains focus; reveal does not make an unavailable selection purchasable. Existing purchase state must drive both controls. |
| Static / accessibility | Same threshold instant; keyboard users can reach original action or bar. Recheck focus obstruction, short heights, virtual keyboard, zoom and viewport changes. |
| Rendering / integration | Medium-high complexity; IO fallback retains original action. Requires changes around `W/sections/monetta-product.liquid:313` and pinned reserves. Adopt only after demonstrating advantage over persistent baseline. |

### 10–15. Deferred/rejected motion comparison

| Candidate / need and precedent | Mobile / desktop; trigger/replay | Proposed properties/timing; loading/interruption | Reduced/static and accessibility | Rendering/support; Shopify integration and decision |
|---|---|---|---|---|
| **10 Editorial entrance:** optional story hierarchy. `A/app/motion.dart:94,154` one-shot/groups; `W/assets/monetta-base.css:557` dormant reveal CSS, no active reveal markup/initializer found. | Both; at most once when nonessential editorial block enters viewport. Never first-viewport purchase information. | If revisited: opacity +Y≤10px/480ms; no per-card stagger. Loaded content visible by default; do not replay on Back or section replacement. | Static headings/sections default; reduced skips entirely. No focus movement or hidden essential content. | IO + CSS feasible; implementation medium because fallback/replay lifecycle matters. **Explore later**, no lab or implementation. |
| **11 Search entrance:** panel origin potentially useful, repeated results not. `W/assets/monetta-predictive-search.js:148` already has 220ms debounce/latest epoch; `:310` keyboard behavior. | Both; keep typing/results instant. Optional once-per-open fade only if later justified. | No result-row slide; no delay added to 220ms request debounce. Old requests invalidate immediately; loading/empty/error text remains static. | Preserve combobox active descendant, Escape and native Tab. Reduced/static is current instant state. | Existing static panel cheapest. Additional fade low effort but little benefit; **reject repeated animation**; no custom library. |
| **12 Loading shimmer:** reassure waiting. `W/assets/monetta-base.css:539` unused demo shimmer 1.3s; `:346` active spinner 700ms linear. | Both; only actual pending state, not decorative looping. | Reject new background-position shimmer. Keep fixed image reservation, text; bounded spinner only while needed. Stop on finish/error/cancel. | Static text/shape under reduced motion; `aria-busy` and truthful status. Empty/success/error surfaces remain readable. | Shimmer paints repeatedly; spinner transform may composite. **Reject persistent shimmer**, retain honest pending states; no timer-based fake progress. |
| **13 Page transitions:** navigation continuity. `A/app/motion.dart:40` native route/edge swipe; `W/assets/base.css:226` legacy view transitions. | Both only if browser supports; browser-native document navigation otherwise. | No chosen timing without spike. Never block navigation for exit; Back/Forward and cancelled transitions must work. | Reduced skips; preserve normal focus/scroll restoration. No essential content hidden pending API. | Cross-document support needs feature detection and browser matrix. Active `W/layout/monetta.liquid:1` excludes legacy runtime; filters are real GET navigations (`monetta-listing.js:17`). **Defer**, no SPA migration or implementation. |
| **14 Fly-to-cart/celebration:** confirm purchase, already served by candidate1. `W/assets/fly-to-cart.js:1`, legacy `base.css:3167` flight 600/800ms. | Both: reject large object travel, especially narrow screens. No celebratory replay. | Existing legacy timing is an exception, not recommended token. Never begin before confirmed success or replay for repeated pending clicks. | Static confirmation/count; no spatial path required to understand result. | Multiple transforms/layers and cross-page coordinates add work. **Reject** flight, confetti and burst; inactive legacy code is not a reason to port it. |
| **15 Automatic gallery/parallax/grid stagger/error shake:** no unmet purchase need. `A/app/motion.dart:14`18s cinematic token; `:94` explicitly excludes product grids. | Both; reject autoplay/scroll-linked decoration and shake. | No proposed duration/sequencing. Product changes occur only after explicit input; no persistent loop or delayed grid availability. | Static images/prices/errors; visible corrective text. Avoid vestibular triggers and controls moving away from activation. | Parallax/large grids risk layers, paint and scroll work. **Reject**; retain native browsing, truthful errors and predictable layout. |

## Primary-source basis and limits

[W3C Animation from Interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html) supports disabling nonessential interaction motion; it is a LevelAAA criterion, not a blanket claim that every animation violates WCAG. [W3C Status Messages](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html) supports announcing outcomes without moving focus. [W3C Focus Not Obscured](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html) matters for sticky chrome.

[MDN dialog](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/dialog), [reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion), [IntersectionObserver](https://developer.mozilla.org/en-US/docs/Web/API/Intersection_Observer_API) and [cross-document View Transitions](https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API/Using#basic_mpa_view_transition) describe capability and fallback requirements. [web.dev animation performance](https://web.dev/articles/animations-guide) explains why transform/opacity are preferable candidates and why actual paint/layer behavior still needs inspection. [Shopify Section Rendering](https://shopify.dev/docs/api/ajax/section-rendering) and [Cart API](https://shopify.dev/docs/api/ajax/reference/cart) constrain state integration.

These references support platform facts. Rankings, amplitudes, target timings and adoption judgments are design recommendations. Actual performed tests and limitations belong to [VALIDATION.md](VALIDATION.md); screenshots alone do not establish animation quality.
