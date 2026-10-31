# Monetta iPhone Duo implementation prompt for Claude Code

You are the senior Flutter/iOS engineer and product designer responsible for implementing Monetta’s iPhone Duo experience. Work directly in this repository and complete the implementation, integration, and verification in this run. Make the changes; do not finish with another plan, estimates, scaffolding, or instructions for someone else to implement.

## Outcome

Deliver one existing Flutter app that feels beautiful and continuous across the Duo outer display, inner landscape, inner portrait, partial folds, and resizable windows. Retain conventional iPhone, supported iPad, and Android behavior.

The central shopping task must work throughout:

> Find a crossbody, filter the collection, open a product, select a variant, unfold into browsing beside product details, inspect another image, add once, fold closed, and continue to the existing native checkout. Canceling checkout returns to the same valid cart.

Keep the existing project, Flutter commerce logic, and normal iOS host. A small Swift adapter belongs inside the existing `ios/Runner/` when verified platform APIs require it. Avoid creating another app, a parallel codebase, or a broad framework migration.

## Read and inspect first, then implement

Read applicable `AGENTS.md` / `CLAUDE.md` instructions and these repository files:

- `README.md`, `.fvmrc`, `pubspec.yaml`, `Makefile`, and `config/README.md`.
- `docs/IPHONE_DUO_DESIGN_AND_LAUNCH_PLAN.md`.
- Inspect the actual image `docs/design/iphone-duo/monetta-duo-design-board.png` and its editable SVG alongside it.
- `design-system/monetta.tokens.json`, `design-system/build.mjs`, `lib/app/theme.dart`, `lib/features/boutique/boutique_tokens.dart`, and `lib/app/text_scale_policy.dart`.
- The actual navigation, home, product, catalog/search, cart, and account screens under `lib/features/` and their existing controllers/tests.
- `ios/Runner/Info.plist`, `AppDelegate.swift`, `SceneDelegate.swift`, and `ShopifyCheckoutBridge.swift`.

The design plan is a researched proposal. Verify its assumptions against the current source, installed SDK headers, current Apple documentation, and observed runtime behavior. Its estimates and suggested filenames are not requirements. The board illustrates layouts; its sample products, prices, and system geometry must not become hardcoded production content.

Use primary documentation where needed:

- https://developer.apple.com/iphone-duo/prepare/
- https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo
- https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
- https://developer.apple.com/videos/play/tech-talks/111462/
- https://developer.apple.com/videos/play/tech-talks/111463/
- https://api.flutter.dev/flutter/widgets/MediaQueryData/displayFeatures.html
- https://docs.flutter.dev/ui/adaptive-responsive/general

Record the initial worktree status and inspect relevant existing diffs. This repository has substantial user work in progress, including files this implementation may need to touch. Preserve it. Apply focused edits; do not reset, clean, stash away, or replace unrelated changes. Keep edits within the Flutter/iOS app, its design tokens, relevant tests, and task documentation. The Shopify theme and backend are outside this task unless a directly demonstrated dependency requires a minimal change.

## Implement this scope

### 1. Establish real geometry and runtime support

Inspect the pinned Flutter engine, Xcode SDK, installed simulator runtimes, iOS host, and current resize behavior. At the earlier review, Flutter was pinned to 3.44.8, Xcode/SDK 27.1 was installed, and only the iOS 27.0 simulator runtime was available. Recheck rather than assuming this is unchanged.

Set up a Duo simulator/runtime through supported tooling if available. Run the actual staging build and establish the current baseline. Keep this investigation short and continue implementing independent Flutter work if runtime installation is unavailable.

Use existing Flutter support if it demonstrably supplies the required information. Otherwise add the smallest availability-guarded Swift bridge that publishes current host bounds, safe insets, usable bar context, size classes, division regions, and occlusion regions. Confirm API signatures against the installed SDK.

Convert all frames into the Flutter host’s coordinate system and logical units. React to layout, safe-area, and trait changes. Detach listeners correctly. Do not invent production hinge rectangles, infer device identity from known screen dimensions, or assume an empty region list means the phone is closed. Synthetic geometry belongs in tests/debug fixtures.

Retain the existing minimum iOS deployment version unless a demonstrated requirement makes that impossible. Guard newer native APIs and keep a working fallback on older supported systems. Make dependency or toolchain changes only when needed and verified.

Verify whether bar-axis traits are meaningful in the actual Flutter host. If a native container is necessary, validate its lifecycle and Flutter-view ownership before adopting it. Prefer the smallest working integration with the current engine/session; do not silently create multiple engines or cart/account instances.

### 2. Build shared adaptive navigation and continuity

Keep four destinations: **Inicio, Catálogo, Carrito, Cuenta**. Preserve access to saved products and existing secondary routes. Give destinations consistent Spanish labels and semantic selected states.

Support the system-appropriate side controls and horizontal controls using verified host context. Account for overflow, short height, camera/status areas, and either side of Split View. A wide window alone is not proof that a right-side Duo rail is appropriate. Flutter custom bars do not receive UIKit behavior automatically.

Measure local content/pane constraints. Define safe-area and navigation-inset ownership once, so they are neither ignored nor applied twice. Keep search, variant selection, and the labeled purchase action in content where they remain readable.

Keep route and shopping state above layout branches: destination/history, query, facets, sort, selected product/variant IDs, result anchor, gallery page, compatible zoom state, expanded sections, drafts/focus, pending cart mutations, and checkout session. Reflow must not recreate services, lose selection, repeat analytics, duplicate Hero tags, or submit mutations twice.

For a product opened from browsing, expansion reveals its source collection beside its details; collapse preserves the active detail and Back restores the same filtered collection position. Direct product links preserve sensible detail navigation and do not fabricate a source collection.

### 3. Implement the product and browsing experience

Extract reusable product content and state from the existing screen rather than maintaining separate compact and expanded product implementations.

- **Compact:** contained gallery, readable name/price/variants, and a reachable primary purchase action. Prevent the gallery from consuming the whole useful viewport on shorter/wider windows.
- **Roomy direct product page:** gallery beside the details and purchase panel.
- **Roomy collection/search/brand:** browsing beside selected product details, preserving filters, sort, count, and result position.
- **Seated/partial fold:** use the actual reserved regions to keep the gallery visible and the purchase/variant controls reachable. Move related controls together; retain all functionality in compact layouts.
- Adapt column counts to actual tile/pane width and text enlargement. A selected browse/detail layout must still leave both regions usable. If space or accessibility text makes two panes unsuitable, reflow to a readable single flow.

Use the plan’s proposed 700/920 content thresholds only as starting hypotheses. Validate and consolidate layout decisions in the existing token system where appropriate. Avoid scattered device-specific constants.

Change generated design values through their source manifest and existing generator. Preserve current edits to that generator; do not manually patch generated Dart token files.

### 4. Finish surrounding surfaces and native handoffs

Reuse the cart’s existing wide layout and adapt it to local constraints, active regions, keyboard, and short height. Keep remote totals and existing payment/cart rules authoritative.

Adapt quick view, filters, settings, notifications, account/orders, and empty/error/offline states so they remain usable when the app resizes. Give sharing a valid source anchor that remains correct after reflow. Keep modal presentation associated with its originating host/scene.

Preserve Shopify Checkout Sheet Kit and the existing OAuth integration. Handle cancellation, return links, and in-flight operations through geometry changes. Use staging/test flows without placing real orders. Preserve existing stock, pricing, variant, apartados, and rewards semantics.

### 5. Preserve Monetta’s visual quality and accessibility

Keep warm ivory, brown actions, restrained decorative gold, Playfair Display editorial roles, Inter controls/prices, full product silhouettes, and real Shopify-driven content. Use the existing dark palette and image/cache components. Keep new work visually consistent with the concept board and existing app identity.

Maintain at least 48×48 logical-pixel interactive targets and the existing approximately 52-pixel primary action height, growing when text requires it. Use semantic labels, visible selection beyond color, logical focus order, and reachable Close/Back actions.

Replace the global text-enlargement cap with layouts that handle the requested system text size. Fix affected customer-facing surfaces rather than shrinking or clipping text to retain a fixed layout. Respect Reduce Motion, Increase Contrast, Bold Text, and Reduce Transparency where relevant.

Let the OS own display-transition motion. Avoid replaying startup animation or building a decorative folding animation during resize. Keep image loading and feedback restrained and responsive.

Comparison, drag-and-drop shopping, Pencil, AR, AI styling, widgets, Live Activities, and multiple independent scenes are outside this implementation. Complete the adaptive shopping experience first.

## Verification is part of implementation

Use the repository’s pinned toolchain through FVM. Read the current staging launch/configuration instructions and reuse existing local configuration without printing sensitive values. Do not substitute production configuration when staging is unavailable.

Run formatting checks on files you edited, Flutter analysis, relevant existing tests, and meaningful new tests. Then run the broader Flutter suite where feasible. Build the iOS simulator app in the appropriate staging flavor. Validate Android compilation when shared/platform-dependent changes warrant it. Follow the actual repository commands rather than assuming an obsolete invocation.

The new tests must exercise behavior, particularly:

1. Change constraints and region snapshots on the **same mounted widget**. Product/variant/image/filter selections and the source anchor survive; no overflow occurs.
2. Select a result, expand/collapse detail, and navigate Back to the same filtered result position.
3. Resize while an add or quantity mutation is pending; exactly one mutation occurs, including failure/retry behavior.
4. Verify that important controls, share anchors, and modal actions fit usable regions with asymmetric insets and active folds.
5. Exercise large system text without the global cap, short heights, keyboard, long Spanish names, sold-out/multi-variant products, and missing images.
6. Verify native handoff cancellation/return behavior through resizing using the supported test paths.

Inspect the rendered app and fix visual defects. Capture the real implemented outer/compact, inner landscape, inner portrait, browse/detail, cart, and large-text states. Exercise partial folds and Split View in the actual Duo runtime when available. Check conventional iPhone and supported iPad layouts, plus Android regressions relevant to shared changes.

Do not treat newly mounting separate compact/expanded apps as proof of continuity. Keep genuine device captures separate from synthetic layout fixtures. Do not overwrite reference goldens merely to hide a regression. Identify pre-existing failures with evidence while preserving the dirty worktree.

If physical hardware or a required runtime is unavailable, explicitly identify the checks you could not perform and continue all independently verifiable work. Do not claim hardware behavior, App Store readiness, or a badge was verified from static screenshots.

## Execution and deliverables

Proceed autonomously through implementation and fixes. Make reasonable decisions from the app and the design intent. Ask only when missing information actually prevents progress. An unavailable external resource should not stop unrelated implementation work.

If your environment supports parallel agents, use them after establishing shared geometry/state interfaces. Delegate bounded layout, native adapter, or review/test tasks with clear file ownership. The lead agent owns integration and resolves shared-state/navigation changes. Agent reports alone are not verification; inspect their code and run integrated checks.

Prepare local release evidence and a screenshot/remaining-hardware checklist. Publishing, uploading builds/assets, production changes, and placing orders are outside this task. Do not mark the App Store badge as completed.

Finish with:

- Implemented code and relevant tests in the existing app.
- Verified screenshots/evidence under a task-specific directory in `artifacts/`, preserving any existing files there.
- `docs/IPHONE_DUO_IMPLEMENTATION_REPORT.md`, recording architecture chosen, implemented behavior, checks/commands and outcomes, evidence paths, pre-existing failures, and any remaining runtime/hardware checks.
- A concise final explanation of what changed, what was verified, and what remains blocked. Clearly distinguish observed behavior from assumptions.

The success criterion is a coherent, attractive, working adaptive Monetta build with preserved commerce behavior and honest verification. Continue until that result is achieved or a specific external blocker prevents the remaining work.
