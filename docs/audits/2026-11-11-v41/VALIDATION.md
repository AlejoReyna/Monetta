# Reproduce the local evidence

Run from `/Users/alexis/theCode/Monetta`, using the existing Flutter dependency cache.
These commands render widgets and run tests; external launchers/services are mocked or disabled. They do not place orders, send messages or change production.

## Asset checks and existing full-page captures — 28 passing checks

```sh
MONETTA_1TO1_CAPTURE_DIR=docs/audits/2026-11-11-v41/evidence \
flutter test --no-pub --reporter expanded \
  test/features/boutique/client_guide_1to1_capture_test.dart \
  test/features/contact/contact_presentation_test.dart \
  test/app/v41_base_tokens_test.dart
```

The `p-*` and `contact-*` images use the existing full-page capture helper, which expands the viewport height. The navigation therefore appears at the bottom of the expanded page. They are useful for checking composition/sequence, not exact first-viewport positioning. Product imagery is controlled by the fixture harness. Account identity, orders and balances in these images are test examples.

## Existing behavior checks — 201 passing checks

```sh
flutter test --no-pub --reporter expanded \
  test/features/catalog/product_card_test.dart \
  test/features/catalog/catalog_filter_panel_test.dart \
  test/features/catalog/collection_screen_test.dart \
  test/features/catalog/search_screen_test.dart \
  test/features/product/product_selection_purchase_test.dart \
  test/features/product/quick_view_purchase_test.dart \
  test/features/product/purchase_dock_test.dart \
  test/features/checkout/shopify_cart_summary_test.dart \
  test/features/checkout/checkout_return_test.dart \
  test/features/orders/orders_screen_test.dart \
  test/features/orders/order_detail_screen_test.dart \
  test/features/account/account_screen_test.dart \
  test/features/favorites/favorites_screen_test.dart \
  test/features/notifications/notifications_screen_test.dart \
  test/features/rewards/rewards_guide_screen_test.dart \
  test/features/wholesale/wholesale_screen_test.dart \
  test/features/navigation/monetta_bottom_navigation_ios_glass_test.dart \
  test/features/navigation/monetta_bottom_navigation_compact_test.dart
```

## Fixed-viewport audit captures — 10 passing checks

```sh
flutter test --no-pub --reporter expanded \
  docs/audits/2026-11-11-v41/render_probes_test.dart
```

These write `viewport-*.png`. The `320-2x` suffix means **320 logical px wide at 200% text scale**, not a 2x image resolution. Images use a 1:1 logical/physical pixel ratio. The sold-out state is deliberately forced on a fixture to inspect that UI; it is not a real inventory observation. The iOS image overrides the Flutter target platform; it is not an installed iOS-device screenshot. Other audit viewport probes use Flutter's default Android target behavior and default host layout context.

Checks assert that a sampled frame renders without exceptions. Review the pixels too: the 320/200% heroes remain unreadable despite passing this assertion. No golden baselines were updated.

The six `*-comparison.jpg` files resize the owner's 780 px reference to 390 logical px, place it beside a 390 px current full-page top crop and label both. They are review aids, not pixel-diff scores. The original owner files remain in Downloads.

## Provenance

`audit-evidence.json` records the reviewed commit, source/reference SHA-256 hashes, contract matrix, asset counts, test counts and limits. The audit targets the existing dirty working tree, including the in-progress v4.1 token/font/assets changes. It is not a review of commit 80735fa alone.
