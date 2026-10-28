# Task: design Monetta for every iPhone Duo posture, and plan its implementation

You are a senior product designer working with an iOS/Flutter engineer. Your job is to **define the right Monetta design for every iPhone Duo posture and window configuration** and turn it into an implementation plan. That covers closed, open, partially folded, rotated, windowed and in transition. This task produces a plan, design specifications and evidence. **Do not change app code.**

The work does not start from zero. An adaptive Duo implementation already exists in an open pull request. Build on it, measure it, and fill its gaps. Do not redesign what already works.

## 1. Read first

Repository: `AlejoReyna/Monetta`. Duo work lives on branch `feat/iphone-duo`, open as PR #35 ("feat(duo): adaptive storefront for iPhone Duo"). The relevant commits are `78a6532` (implementation), `d4f7b9e` (report and evidence) and `738a61f` (bridge built only with the iOS 27.1 SDK).

Read these files on `feat/iphone-duo`, in this order:

1. `docs/IPHONE_DUO_DESIGN_AND_LAUNCH_PLAN.md`: product decision, Apple guidance, layout rules, screen-by-screen intent, backlog DUO-01–DUO-10, validation gates.
2. `docs/IPHONE_DUO_IMPLEMENTATION_REPORT.md`: what was built, how it was verified, what remains unverified.
3. `docs/design/iphone-duo/monetta-duo-design-board.svg` (and `.png`): concept board covering only the outer display, inner landscape browse + detail, and "seated".
4. `artifacts/iphone-duo/README.md`, then `resume-runtime-summary.json`, `runtime-captures/`, `apple-reserved-regions.md` and `apple-bar-edge.md`.
5. Code:
   - `ios/Runner/SceneDelegate.swift`: geometry bridge.
   - `lib/platform/system_layout_context.dart`: immutable snapshots of bounds, safe insets, bar edge, size classes, and division and occlusion regions.
   - `lib/app/storefront_layout.dart`: app thresholds.
   - `lib/features/navigation/adaptive_storefront_scaffold.dart`
   - `lib/features/catalog/browse_detail_layout.dart`
   - `lib/features/product/product_adaptive_body.dart`
   - `lib/features/checkout/checkout_screen.dart`
   - `integration_test/duo_shopping_task_test.dart`
6. Design system: `design-system/monetta.tokens.json`, `lib/app/theme.dart`, `lib/app/motion.dart`.
7. Motion research, on branch `claude/determined-wozniak-waw24s`, in `docs/research/monetta-motion-evidence-2026-10-27/`: `INVESTIGACION_V2.md`, `LOGO_Y_ENTREGA.md` and `REFERENCIAS_COMERCIALES.md`. The welcome logo is written letter by letter. That decision constrains the Welcome screen in every posture (see section 5).

## 2. What is already established

**Architecture.** One Flutter engine. A small availability-guarded bridge in `SceneDelegate.swift` streams UIKit geometry to Dart: `UIView.reservedRegions(kind:options:)` for division and occlusion regions, `UITraitCollection.verticalBarEdge`, safe insets and size classes. Dart rejects stale snapshots.

- `AdaptiveStorefrontScaffold` draws the four destinations (Inicio, Catálogo, Carrito, Cuenta) as a rail on the system bar edge, or as a reflowing horizontal bar.
- `BrowseDetailLayout` keeps the source collection mounted beside the product.
- `ProductAdaptiveBody` splits gallery and purchase controls into usable regions.
- Older Xcode builds compile without the bridge and report `"supported": false`. That is the fallback path.

**Geometry measured on the Duo simulator.** iOS 27.1, logical points, from `resume-runtime-summary.json` and the implementation report. Simulator data, not hardware:

| Stage | Window | Bar edge | Division region |
|---|---|---|---|
| Closed, outer portrait | 466 × 678 | right (84 pt right inset, 34 pt bottom) | none; camera occlusion present |
| Open, inner landscape | 951 × 669 | right | vertical band x 455.5, width 40, **inactive** |
| Partial fold (book) | 951 × 669 | right | same vertical band, **active** |
| Open, inner portrait | 669 × 951 | none (horizontal bars) | horizontal band y 455.5, height 40, inactive |
| Closed, outer landscape | 678 × 466 | right | none |

**Verified on the simulator.** One mounted shopping session survived outer → inner landscape → partial fold (book) → flat → inner portrait → closed.

- Product, variant and gallery state persisted.
- The purchase action avoided active regions.
- Exactly one cart line was added.
- The cart was captured at the largest accessibility text size.
- The full suite has 1376 passing tests; 8 golden failures already existed on the base.

**Not verified yet:**

- Physical hardware.
- **Inner portrait with an active horizontal division**, the tabletop or "seated" posture. The board draws a seated layout, but the runtime walkthrough only folded in landscape (book).
- Live Split View and window resizing.
- Tent or stand use.
- VoiceOver.
- Native share, OAuth and Shopify checkout sheets during transitions.
- Performance and memory under repeated folding.
- Most screens per posture: Welcome, Inicio beyond the outer capture, Search, Guardados, Filters, Quick view, Cuenta, Pedidos, Rewards, Notifications and Settings.

**Product principles to keep:**

- "More room to choose": the larger display improves decisions; it does not just enlarge components.
- The same hierarchy and functionality in every posture.
- No step of the signature task is reserved for the inner display.

Signature task: *find a brown crossbody, inspect it, choose a variant, buy it.*

## 3. Postures and configurations to cover

**Verify this inventory before designing.** Use Apple's current documentation (the plan links developer.apple.com/iphone-duo, the HIG page "designing for iPhone Duo", and the tech talks 111462 and 111463) and the Duo simulator. For each row, record its source, or mark it "not available on Duo" with the source that says so. Do not assume a posture exists because other foldables have it.

| ID | Posture / configuration | What to establish |
|---|---|---|
| P1 | Closed, outer display, portrait | Baseline compact experience; side rail on the reported bar edge; camera occlusion. |
| P2 | Closed, outer display, landscape | Short height (≈466 pt): what collapses, what scrolls, where the primary action sits. |
| P3 | Open flat, inner landscape ("double" width, book orientation) | Two-pane layouts; the inactive division as a guide, not a wall. |
| P4 | Open flat, inner portrait | Horizontal bars; tall single-column or stacked panes. |
| P5 | Partially folded, book (inner landscape, vertical division active) | Each pane wholly inside one side; no control straddles the fold. |
| P6 | Partially folded, tabletop / "seated" (horizontal division active) | Reproduce it on the simulator. If it exists: content above the fold, controls below. If the Duo cannot produce it, say so and retire the board's seated layout or redefine it. |
| P7 | Tent / stand | Whether it exists on Duo and which display is used. The current plan only requires the outer experience to stay usable. |
| P8 | Windowed on the inner display: Split View on both sides, resizable extremes, Slide Over if it exists | The bar edge can change; never assume "right rail on any wide window". |
| P9 | "Both displays at once" | Whether iOS 27.1 lets one app use the outer and inner displays simultaneously. If not, record "not applicable" with the source. If yes, propose the smallest useful use or explicitly defer it; the existing plan excludes it from launch. |
| P10 | Transitions | Opening, closing, rotating and partially folding mid-task, with the keyboard up, a sheet open, an add-to-cart in flight, and checkout or OAuth in progress. |

Apply these **overlays** to every posture:

- Largest accessibility text, Bold Text, Increase Contrast.
- Reduce Motion, Reduce Transparency.
- VoiceOver, hardware keyboard and focus.
- Dark mode.
- Long Spanish product names.
- Empty, error and offline states.

## 4. Screens to specify per posture

**Bespoke designs:**

- Welcome and onboarding (logo).
- Inicio.
- Catálogo, collection and brand.
- Search.
- Product: browse + detail, and direct or deep link.
- Filters and sort.
- Quick view.
- Guardados.
- Carrito.
- Checkout handoff (native Shopify sheet).
- Cuenta.
- Pedidos and order detail.

**Rule-based** (write one inheritance rule each, not a full design): Rewards, Notifications, Settings, Mayoreo / partner, Contacto, About. Admin screens are internal; state the rule in a single line.

For every **posture × screen** cell, specify:

1. **Layout:** panes and ratios expressed against measured regions, never fixed device widths; what is visible in the first viewport.
2. **Navigation:** bar axis and edge, as reported by the host; overflow behavior; Back.
3. **Primary action:** location relative to divisions, occlusions and the bar.
4. **Sheets and modals:** which region they occupy and where Close is.
5. **Typography and imagery:** contained packshots, never stretched; full handles.
6. **Continuity on entering and leaving the posture:** what state persists and where focus lands.
7. **Motion:**
   - The system owns fold and rotation transitions.
   - Content crossfades of 160–220 ms are allowed only where they clarify a pane change.
   - No simulated fold animation; no startup replay after a resize.
   - Reduced-motion equivalent for each.
8. **Accessibility fallback:** when two panes stop fitting at large text, collapse to a single readable flow.

A cell may say "inherits P*n* because …". It may not be blank.

## 5. Cross-constraints

- **Welcome logo.** Per the motion research, the Monetta logo is written once, M‑O‑N‑E‑T‑T‑A, in about 1000 ms, on the first welcome. On Duo:
  - Folding, unfolding or rotating during the animation must not restart it. Finish it or jump to the final frame.
  - It must never replay after a resize.
  - "Comenzar" is reachable from the first frame and outside occlusions and active divisions.
  - The logo box keeps its final size and position for the posture it starts in.
  - Reduce Motion shows the complete logo.
  - Specify P1, P3 and P4 explicitly.
- **Geometry ownership:**
  - Never infer the device or the posture from width alone.
  - Use the reported snapshot. Treat the 84 pt inset and the 40 pt band as runtime observations, not constants.
  - Do not stack two safe-area paddings or add an invented hinge gap.
  - Thresholds stay in `lib/app/storefront_layout.dart`, or in the tokens if you justify moving them.
- **Continuity:**
  - Selection uses product and variant IDs.
  - No layout change may duplicate a mutation, a checkout launch, an OAuth request or an analytics impression.
- **Brand:**
  - Warm ivory `#FBF8F2`, brown action `#745237`, ink `#211B16`.
  - Gold `#C5A052` for decoration only (2.32:1 contrast).
  - Playfair Display for editorial roles, Inter for controls.
  - 48 × 48 minimum targets, a Monetta standard, not an Apple rule.
  - UI copy stays in Mexican Spanish.
- **Honesty:**
  - Concept boards are labeled "concept".
  - Simulator captures are labeled "simulator".
  - Synthetic geometry in widget tests is labeled "synthetic".
  - Nothing is described as verified on hardware.

## 6. Process

1. **Baseline.** Use the dedicated Duo simulator (`Monetta Duo Implementation`). If it is missing, follow the report's setup, and **ask the owner before downloading or installing any runtime**. Run the current `feat/iphone-duo` build and capture each key screen in P1–P8 with the geometry log. Use the existing driver (`test_driver/iphone_duo_driver.dart`) and the `debugMonettaFixtureImage` stand-in photo, so captures are not empty placeholders.
2. **Verify the posture inventory** (section 3), with a source per row.
3. **Design** the matrix (section 4), starting with the signature task across every posture, then the remaining screens.
4. **Gap analysis.** For each cell, compare the current capture with the spec and classify it:
   - ✅ matches
   - ⚠ partial
   - ❌ missing
   - ❓ unverifiable without hardware

   Cite `file:line`.
5. **Plan.** Turn the gaps into a backlog.
6. **Self-review** against the acceptance criteria in section 8 before handing off.

## 7. Deliverables

Work on a new branch from `feat/iphone-duo` named `docs/iphone-duo-postures`. Do not push to `feat/iphone-duo` and do not open a PR unless asked. Put everything in `docs/iphone-duo-postures/`:

1. `POSTURES.md`: the verified inventory (P1–P10), geometry per posture, and sources (Apple URL, or simulator log and capture). States what Duo does not support.
2. `DESIGN_SPEC.md`: the posture × screen matrix and per-screen specifications, rules, thresholds and tokens.
3. `board/`: an updated concept board (SVG plus PNG) showing every supported posture for the signature task, and the Welcome screen in P1, P3 and P4. Labeled "concept".
4. `captures/`: current simulator captures per posture and screen, with a JSON log of geometry, text scale and checksum.
5. `GAP_ANALYSIS.md`: the cell-by-cell status table with evidence and `file:line`.
6. `IMPLEMENTATION_PLAN.md`:
   - Backlog items continuing the existing numbering (DUO-11 onward), each with priority (P0, P1 or P2), dependencies, acceptance criteria and tests to add: labeled synthetic-geometry widget tests, and one `flutter drive` posture walkthrough per new posture.
   - Effort ranges labeled as estimates.
   - Risks and decision gates.
   - Open questions for the owner, for example: is tent support worth anything; Split View priority; the seated trigger; dual-display use.
7. `HARDWARE_TEST_SCRIPT.md`: the step-by-step physical-device protocol for when a Duo is available. Covers reach, occlusion, VoiceOver, sheets, checkout cancel and return, and repeated-fold memory traces.
8. `README.md`: a one-page summary separating **verified (simulator)**, **specified (design)** and **assumed / unverifiable**.

## 8. Acceptance criteria for this plan

- Every supported posture × bespoke screen cell is specified. Every rule-based screen has its inheritance rule.
- Every posture claim has a source, or is marked unverified.
- P6 (seated) and P9 (both displays) end with an explicit, sourced decision.
- The signature task is walked through, step by step, in every supported posture, including mid-task transitions (P10).
- The Welcome logo behavior is specified for P1, P3, P4 and transitions, and matches the motion research.
- Accessibility overlays are applied to every bespoke screen, at least at the rule level.
- Backlog items trace to gaps, and gaps trace to captures or code references.
- Nothing claims hardware verification, App Store readiness or badge approval.

## 9. Do not

- Change app code, goldens, comparator tolerances, analyzer rules or dependencies.
- Install runtimes or tools without the owner's approval, or commit the runtime export or build products.
- Perform live Shopify, commerce or checkout actions. CI defines keep commerce disabled.
- Invent device specifications, Apple requirements or screenshots. Present concept art as captures.
- Hardcode device detection by width, a fixed hinge gap or the observed inset values.
- Add Duo-only features to the launch scope (comparison, drag, Pencil, AR, multiwindow) unless the owner asks. They stay in P1/P2 of the backlog.
