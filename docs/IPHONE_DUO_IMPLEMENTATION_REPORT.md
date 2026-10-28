# iPhone Duo implementation report

Status: local implementation, automated checks and Duo simulator walkthrough completed; ready for independent review with the recorded baseline golden exceptions. Physical-device and release acceptance remain unexecuted.

## Isolation

- Worktree: `/Users/alexis_reyna/MyCode/Monetta/.claude/worktrees/iphone-duo`
- Branch: `feat/iphone-duo`
- Approved base: `feat/client-guide-borrador-1to1`
- Base and current HEAD: `40567de777ab1d187438edec2ae8e88fc5a7d22d`
- Dirty worktree; no commits, push, merge, deployment, or Shopify operation.
- Initial inspection confirmed the target branch and directory were absent. Created with the exact authorized `git worktree add --no-track -b feat/iphone-duo .claude/worktrees/iphone-duo feat/client-guide-borrador-1to1` command.
- Only the authorized Duo plan and design board directory were copied from the main checkout, after confirming destination absence. No uncommitted application changes were copied. Other worktrees/devices remain untouched.

## Implemented architecture

One existing Flutter engine and the existing service composition and Navigator stack remain authoritative. `SystemLayoutHost` subscribes once above the navigator. `SceneDelegate.swift` adds a small availability-guarded stream bridge and a noninteractive geometry probe to the existing Flutter host. UIKit region reads in `updateConstraints()` register automatic invalidation; layout, safe-area and bar-trait changes coalesce into immutable snapshots. Canceling the Dart listener removes the probe and trait registration. Scene disconnection removes the stream handler. No extra engines or UIKit bar containers were introduced.

Snapshots contain the host bounds, safe insets, system preferred bar edge, size classes, active/inactive division regions and active occlusions. UIKit frames already include their interactive margins and are converted to host coordinates. Dart rejects stale sequences and snapshots with the wrong rotation basis. `ViewRelativeLayout` measures pane origins after layout; controls wait for the corrected local basis. Active divisions also feed Flutter's display-feature contract so anchored Flutter sheets can select a usable region.

`AdaptiveStorefrontScaffold` explicitly renders Flutter chrome. It uses the system bar edge, not a width-derived device guess. A reported side inset that already contains the shared bar is consumed once and used for the rail; the observed 84-point inset is runtime data, not a production constant. Rail controls avoid active regions. Horizontal navigation measures requested text and reflows into fewer columns without capping its scaler; short windows expose the same four destinations through overflow. Selection has semantic and non-color cues. Existing secondary routes and saved products remain reachable. Cart gains this shared chrome on API-capable hosts while the existing focused cart presentation remains the unsupported-host fallback.

`BrowseDetailLayout` retains the mounted collection/search/brand/saved source and selected product. It preserves applied and draft filters, query controllers, sorting and source navigation. Result anchors use product IDs and viewport alignment; the selected/visible anchor is kept alive only through restoration. Product state remains mounted when a pane becomes a page. Back restores the source anchor and focus; direct products have no fabricated browsing source. Hero flights are disabled only within the simultaneously visible browse/detail surface.

`ProductAdaptiveBody` contains the gallery at compact sizes and puts it beside details when local width, height and requested text permit. Actual division geometry places gallery and purchase-control groups in separate usable regions. Short/occluded regions fall back to a readable scrolling flow. Stable gallery/detail subtrees retain page, zoom state, selected variant ID, open sections and pending operations. Sharing obtains a fresh source rectangle and includes a product link only when public configured store identity is available.

The cart's existing reconciliation and split layout remain in place, now using local constraints and a usable-region surface. Account/order bodies use the same usable-region handling. Quick view and filters retain their existing stateful implementations and receive current source anchors and safe-area handling. No commerce, database, credential, reward, permission, domain-normalization, checkout SDK boundary or account-scope implementation was changed.

## Platform evidence and API boundary

Inspected the pinned Flutter engine (`058e0af2c2` framework, `0cd610717b` engine revision) and `engine/src/flutter/shell/platform/darwin/ios/framework/Source/FlutterViewController.mm`. It forwards `safeAreaInsets` into viewport padding (lines 1562–1565); searches of the pinned iOS source and Flutter framework for `reservedRegions` and `verticalBarEdge` found no forwarding API. This is the reason for the small bridge, rather than assuming UIKit behavior changes Flutter widgets automatically.

Installed SDK: `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator27.1.sdk`. Inspected public `UIVerticalBarEdge.h` and the reserved-region Swift interface. Consulted current official [Apple region documentation](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)), [bar-context documentation](https://developer.apple.com/documentation/uikit/uitraitcollection/verticalbaredge) and [Flutter adaptive-layout guidance](https://docs.flutter.dev/ui/adaptive-responsive/general). The current Flutter guide describes a newer release, so compatibility decisions use pinned source and a successful native build. Apple Markdown evidence is preserved in `artifacts/iphone-duo/apple-reserved-regions.md` and `apple-bar-edge.md`.

## App-only geometry adapter

`lib/app/storefront_layout.dart` centralizes pane gap, split width/height, minimum pane widths, fallback rail width, cart split width, minimum task height and grid density. These are app presentation decisions, not device/hinge specifications. Existing brand colors, typography and generated/shared token files are reused unchanged. No shared token regeneration or generated token patching occurred.

## Toolchain and runtime

- Flutter 3.44.8 through FVM; Dart 3.12.2.
- Xcode 27.1 (27A9275), simulator SDK 27.1; deployment minimum unchanged.
- Initially only iOS 27.0 was installed. Dedicated Duo creation failed with `SimError code=403: Incompatible device` (exit 147), recorded in `simulator-create.log`.
- The user explicitly authorized iOS 27.1 installation with “Do it”. Executed `xcodebuild -downloadPlatform iOS -buildVersion 27.1 -architectureVariant arm64 -exportPath artifacts/iphone-duo/runtime-download`. Installation succeeded: iOS 27.1 (24A94232).
- Dedicated simulator: `Monetta Duo Implementation`, UUID `A38CDB10-3E59-4575-A58C-4E1072B8A4CC`. First boot printed `Data Migration Failed` despite exit 0. Read-only health checks subsequently confirmed SpringBoard and both displays; actual native app testing then passed. Other booted devices were preserved.
- Runtime download/export and all task evidence reside under `artifacts/iphone-duo/`; do not commit the runtime export or build products.

## Verification

- `fvm flutter pub get --offline`: passed with cached packages; dependency versions unchanged (`pub-get.log`).
- Baseline `fvm dart format --output=none --set-exit-if-changed lib test integration_test`: passed, 383 files, no changes (`baseline-format.log`).
- Baseline `fvm flutter analyze --no-pub`: passed (`baseline-analyze.log`).
- Baseline `fvm flutter test --no-pub`: exit 1, 1361 passed, 5 existing skips and 8 pre-existing UI-04 golden failures. Exact differences in `baseline-test-summary.txt`; comparison images preserved in `baseline-golden-failures/`. The user explicitly authorized continuing with these baseline failures recorded and existing goldens unchanged.
- Baseline `fvm flutter build ios --simulator --debug --no-pub --dart-define-from-file=config/dart_defines.ci.json`: passed; `build/ios/iphonesimulator/Runner.app` (`baseline-ios-build.log`). CocoaPods installed against the committed lock; no native dependency upgrade.
- `fvm flutter test --no-pub integration_test/duo_geometry_smoke_test.dart -d A38CDB10-3E59-4575-A58C-4E1072B8A4CC --dart-define-from-file=config/dart_defines.ci.json`: passed on the actual Duo runtime (`native-geometry-spike.log`). Outer view measured 466×678 logical points, right inset 84, bottom inset 34, right bar preference and active occlusion frames. This verifies the bare Flutter host can deliver the needed context; it is not hardware evidence.
- `test/platform/system_layout_context_test.dart`: passed; stale snapshot rejection, current-size basis, active/inactive region exclusion and subscription cancellation tested.
- Focused regression command covering navigation, Home clearance, grid/packshot behavior, product Back/header, collection artwork and continuity: **145 passed** (`regression-fixes-test.log`).
- New product continuity and navigation tests: **9 passed** (`duo-targeted-test.log`): same mounted widget, selected variant/gallery/expanded sections, visible result ID without selection, browse expansion/collapse/Back, real filter/sort drafts and applied results, one in-flight add, active fold/camera/asymmetric insets/keyboard, full requested fallback-font size, overflow and side-inset ownership.
- `fvm flutter test --no-pub test/features/checkout/duo_checkout_continuity_test.dart test/features/navigation/duo_navigation_test.dart`: **4 passed** (`checkout-navigation-test.log`). The same mounted fake checkout retains the contact draft and one pending launcher across resizing; cancellation preserves cart and exact variant.
- Final `fvm dart format --output=none --set-exit-if-changed lib test integration_test`: passed, **396 files, 0 changes** (`gate-format.log`).
- Final `fvm flutter analyze --no-pub`: passed, **No issues found** (`gate-analyze.log`).
- Final `fvm flutter test --no-pub`: **exit 1, 1374 passed, 5 existing skips, the same 8 baseline golden cases fail** (`gate-test.log`). No new non-golden failures remain. This is a recorded baseline exception authorized by the user, not a passing full test gate. Final comparison images reside in `final-golden-failures/`; `gate-test-summary.txt` lists the exact final deltas. `golden-failure-output/` retains older intermediate output, including obsolete Bag comparisons; Bag passed in the final run. The same failing case names do not imply byte-identical differences: the intentionally condensed product layout changes its golden deltas substantially.
- `fvm flutter build apk --no-pub --debug --flavor staging --dart-define-from-file=config/dart_defines.ci.json`: passed in 655.2 seconds, `build/app/outputs/flutter-apk/app-staging-debug.apk` (`android-build.log`). Existing Gradle/Kotlin/SDK deprecation warnings remain; no dependency or SDK upgrades were made.
- Existing golden files, comparator tolerances, skipped tests and analyzer configuration have not been changed. Compact typography tests now load the actual bundled fonts; separate wide fallback-glyph tests assert uncapped reflow. Grid tests check every price while scrolling through one-column accessibility layouts. The Back test uses Back rather than Inicio.

## Final accessibility fixes and resumed verification

Screenshot review of the earlier native run found clipped progress numerals, a cart badge extending beyond its rail button, and insufficient cart title/name reflow at the largest text setting. The cart now presents a readable current-step sentence, stacks its heading and item count, lets product names wrap fully, and grows quantity controls with the requested text size. The rail places an enlarged quantity below its icon inside the same action; its tooltip retains the exact count. Neither layout caps the requested scaler.

- `fvm dart format --output=none --set-exit-if-changed lib test integration_test test_driver`: **passed**, 397 files, 0 changes (`resume-format-final.log`).
- `fvm flutter analyze --no-pub`: **passed**, no issues (`resume-analyze-final.log`). Five missing trailing-comma diagnostics from the interrupted work were corrected; the earlier result is preserved in `resume-analyze.log`.
- `fvm flutter test --no-pub test/features/checkout/duo_checkout_continuity_test.dart test/features/navigation/duo_navigation_test.dart test/features/product/duo_continuity_test.dart test/platform/system_layout_context_test.dart`: **15 passed** (`resume-targeted-test.log`). This includes full-size text, cart heading/name/quantity bounds, the rail count inside its action, pending checkout cancellation, product state, and native stream lifecycle.
- `fvm flutter test --no-pub`: **exit 1, 1376 passed, 5 existing skips, the same 8 baseline golden failures** (`resume-full-test.log`, `resume-full-test-summary.txt`). The failure names and numeric image deltas match the preceding full gate; no additional failing case appeared. New comparison output is preserved in `resume-golden-failures/`. Expected goldens, tolerances, skips and analyzer rules remain unchanged.
- Rebuilt and ran the documented `flutter drive` command on the dedicated Duo simulator: **passed** (`resume-runtime-shopping-task.log`). The final incremental Xcode build took 30.6 seconds. On the same mounted shopping session, outer → inner landscape → active partial fold → flat → inner portrait → closed preserved product/variant/gallery state and returned from a direct product route to the existing browsing selection. The primary action avoided active regions and added exactly one local unit.
- The first resumed native attempt tapped before the view-origin correction finished and therefore added nothing. Its failed result remains in `resume-runtime-shopping-tap-timing.log`. The integration harness now waits for settled layout after a pose and explicitly requires a hit-testable primary button before tapping. The complete rerun passed; no tap warning was suppressed.
- The final run captured **nine** native images, including separate enlarged heading/progress and quantity-control views. Maximum system category was `accessibility-extra-extra-extra-large`; the runtime reported 16-point text growing to **49.88235 points**. `resume-runtime-summary.json` records each capture's native geometry, text scale and SHA-256. All nine images were inspected, including the uncropped step sentence, stacked heading, contained rail count and readable quantity numeral. Content outside the current scroll viewport in a capture is not a text-line truncation.
- Previous screenshots are preserved in `runtime-captures-before-accessibility-fix/`. Current `runtime-captures/*-fixture-photos.png` files are the successful final run. Ordinary unavailable-network screenshots remain separately named.
- Final source review covered the tracked application diff and new geometry/layout/navigation files; `git diff --check` passed. `changed-files.txt` lists all 42 implementation/test files for review. No commit, push, merge, deployment or live commerce action occurred.

## Remaining acceptance checks

The local checks above are complete. Independent review is still required; the full suite is not green because of the documented baseline golden exception. Physical Duo ergonomics, native sharing/OAuth/Shopify sheet behavior, VoiceOver, live Split View, and release performance/memory traces remain unverified. Conventional iPhone/iPad layouts are covered by the Flutter regression suite; this continuation did not run their native simulator walkthroughs. CI defines intentionally disable live commerce, so the successful native shopping test is not evidence of a real checkout cancellation or payment. The fake checkout cancellation across resizing is covered by the widget test. No physical hardware, App Store readiness or badge approval is claimed.

## Runtime shopping walkthrough

The local driver is `test_driver/iphone_duo_driver.dart`; target is `integration_test/duo_shopping_task_test.dart`. Run with `fvm flutter drive --no-pub -d A38CDB10-3E59-4575-A58C-4E1072B8A4CC --driver=test_driver/iphone_duo_driver.dart --target=integration_test/duo_shopping_task_test.dart --dart-define-from-file=config/dart_defines.ci.json`.

Use only the dedicated Device Hub window. The test opens Catálogo → Crossbody, selects a fixture product, changes a variant when available, and waits at logged `DUO_STAGE` markers. Open and rotate the dedicated simulator for `open-landscape`, partially fold for `partial-fold`, reopen for `open-flat`, rotate for `inner-portrait`, and close for `closed-again`. It checks mounted state and IDs, opens a direct product route without a fabricated source, checks purchase bounds against active regions, adds exactly one local item, and captures cart. For `accessibility-text`, set only the dedicated simulator's system text size to `accessibility-extra-extra-extra-large` (for example with `simctl ui`). The harness captures the heading/progress before scrolling to the quantity control. CI defines disable live commerce; the test explicitly asserts there is no Shopify CartScope before purchase.

Screenshots are written to `artifacts/iphone-duo/runtime-captures/`. Captures suffixed `fixture-photos` use the existing `debugMonettaFixtureImage` hook with bundled `assets/images/home_bag_crossbody.webp`: a deterministic offline photography stand-in, not a claim that every catalog record has that photograph. Native window, safe-area, division, occlusion and bar geometry are unmodified. Preliminary unsuffixed captures show the ordinary unavailable-network image placeholder. No production image code was changed for evidence. Synthetic geometry appears only in labeled widget tests, never in the runtime shopping target.

## Installed manual preview

After the user requested a hands-on build, installed the ordinary `lib/main.dart` application on `Monetta Duo Implementation` (`A38CDB10-3E59-4575-A58C-4E1072B8A4CC`). It is named **Monetta Staging**, bundle `mx.monetta.monettaApp.staging`. The existing public staging defines at `/Users/alexis_reyna/MyCode/Monetta/config/dart_defines.staging.json` passed the repository validator and were referenced directly without copying or printing their values.

Launch command: `fvm flutter run --no-pub --debug --target=lib/main.dart -d A38CDB10-3E59-4575-A58C-4E1072B8A4CC --dart-define-from-file=/Users/alexis_reyna/MyCode/Monetta/config/dart_defines.staging.json`. The existing default Debug configuration already uses the staging display name, bundle ID and OAuth callback scheme. An initial explicit staging-scheme build was interrupted while recompiling native dependencies; the cached Debug configuration completed successfully in 42.0 seconds.

Detached with `d`, preserving the installed and running app. Verified its installation with `simctl get_app_container`, then returned to Home and reopened **Monetta Staging** from its icon on page 2. Left the welcome screen with **COMENZAR** visible for the user's manual test. This normal build uses the existing staging configuration; the automated screenshot/commerce-isolation evidence above still refers to the CI/offline test build.

## Physical-device checklist (unexecuted)

Requires a user-provided, authorized physical Duo: real fold touch reach and occlusion behavior; VoiceOver and hardware-keyboard focus; largest system text, Bold Text, Increase Contrast and reduced motion; share/OAuth/checkout sheet presentation and cancellation/return; background/foreground and repeated fold memory/performance traces. No hardware ergonomics, App Store readiness, badge or independent approval is claimed.

## Changed files

Current source/test inventory is `artifacts/iphone-duo/changed-files.txt`. In a dirty worktree, an auditor must inspect both `git diff 40567de777ab1d187438edec2ae8e88fc5a7d22d` and the listed new files; plain `git diff` omits untracked implementation files. The Duo plan, design board and this report are separate task documentation.

- `integration_test/duo_geometry_smoke_test.dart`
- `integration_test/duo_shopping_task_test.dart`
- `ios/Runner/SceneDelegate.swift`
- `lib/app/storefront_layout.dart`
- `lib/features/account/account_screen.dart`
- `lib/features/boutique/client_guide_scaffold.dart`
- `lib/features/catalog/brand_screen.dart`
- `lib/features/catalog/browse_detail_layout.dart`
- `lib/features/catalog/catalog_browse_screen.dart`
- `lib/features/catalog/collection_screen.dart`
- `lib/features/catalog/product_card.dart`
- `lib/features/catalog/product_tile.dart`
- `lib/features/catalog/search_screen.dart`
- `lib/features/checkout/checkout_screen.dart`
- `lib/features/checkout/mini_cart.dart`
- `lib/features/favorites/favorites_screen.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/navigation/adaptive_storefront_scaffold.dart`
- `lib/features/navigation/guide_chrome.dart`
- `lib/features/navigation/monetta_bottom_navigation.dart`
- `lib/features/navigation/storefront_destination_navigation.dart`
- `lib/features/navigation/storefront_pane_scope.dart`
- `lib/features/orders/order_detail_screen.dart`
- `lib/features/orders/orders_screen.dart`
- `lib/features/product/product_adaptive_body.dart`
- `lib/features/product/product_screen.dart`
- `lib/features/product/quick_view.dart`
- `lib/main.dart`
- `lib/platform/system_layout_context.dart`
- `test/app/media/packshot_fit_test.dart`
- `test/features/catalog/catalog_edge_grid_test.dart`
- `test/features/catalog/collection_guide_photo_test.dart`
- `test/features/catalog/product_tile_card_default_test.dart`
- `test/features/checkout/duo_checkout_continuity_test.dart`
- `test/features/home/home_bottom_clearance_test.dart`
- `test/features/navigation/duo_navigation_test.dart`
- `test/features/navigation/monetta_bottom_navigation_compact_test.dart`
- `test/features/navigation/monetta_bottom_navigation_test.dart`
- `test/features/product/duo_continuity_test.dart`
- `test/features/product/product_header_test.dart`
- `test/platform/system_layout_context_test.dart`
- `test_driver/iphone_duo_driver.dart`
