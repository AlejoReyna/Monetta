import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/app/storefront_layout.dart';
import 'package:monetta_app/features/checkout/mini_cart.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/main.dart' as app;
import 'package:monetta_app/platform/system_layout_context.dart';

/// Real Duo runtime poses are changed only on the dedicated simulator through
/// Device Hub. No synthetic size/region override is used by this test.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'offline shopping continues through actual Duo runtime poses',
    (tester) async {
      // Offline photo stand-in only; actual native geometry remains untouched.
      debugMonettaFixtureImage =
          const AssetImage('assets/images/home_bag_crossbody.webp');
      addTearDown(() => debugMonettaFixtureImage = null);
      await app.main();
      final catalog = find.byKey(const Key('bottom-nav-catalog'));
      final welcome = find.byKey(const ValueKey('welcome-start-button'));
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (welcome.hitTestable().evaluate().isNotEmpty) {
          await tester.tap(welcome);
          final skip = find.byKey(const ValueKey('onboarding-skip'));
          for (var j = 0;
              j < 30 && skip.hitTestable().evaluate().isEmpty;
              j++) {
            await tester.pump(const Duration(seconds: 1));
          }
          expect(skip.hitTestable(), findsOneWidget);
          await tester.tap(skip);
          await tester.pump(const Duration(seconds: 1));
          break;
        }
        if (catalog.hitTestable().evaluate().isNotEmpty) break;
      }
      expect(catalog.hitTestable(), findsOneWidget);

      SystemLayoutContext geometry() => tester
          .widget<SystemLayoutScope>(find.byType(SystemLayoutScope).first)
          .geometry;
      Future<void> waitPose(
        String stage,
        bool Function(SystemLayoutContext) ready,
      ) async {
        debugPrint('DUO_STAGE:$stage');
        for (var i = 0; i < 240; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (ready(geometry())) {
            await tester.pumpAndSettle();
            debugPrint('DUO_GEOMETRY:${jsonEncode({
                  'stage': stage,
                  'size': [
                    geometry().viewSize.width,
                    geometry().viewSize.height,
                  ],
                  'barEdge': geometry().barEdge.name,
                  'divisions': [
                    for (final r in geometry().divisions)
                      {
                        'active': r.active,
                        'frame': [
                          r.bounds.left,
                          r.bounds.top,
                          r.bounds.width,
                          r.bounds.height,
                        ],
                      },
                  ],
                })}');
            return;
          }
        }
        fail('Dedicated simulator did not reach pose $stage');
      }

      Future<void> capture(String name) async {
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        final g = geometry();
        debugPrint('DUO_CAPTURE_CONTEXT:${jsonEncode({
              'name': name,
              'size': [g.viewSize.width, g.viewSize.height],
              'barEdge': g.barEdge.name,
              'safeInsets': [
                g.safeInsets.left,
                g.safeInsets.top,
                g.safeInsets.right,
                g.safeInsets.bottom,
              ],
              'scaled16': MediaQuery.textScalerOf(
                tester.element(find.byType(Scaffold).last),
              ).scale(16),
            })}');
        await binding.takeScreenshot('$name-fixture-photos');
        debugPrint('DUO_CAPTURE:$name');
      }

      await waitPose(
        'outer',
        (g) =>
            g.supported &&
            g.divisions.isEmpty &&
            g.barEdge != SystemBarEdge.none,
      );
      await capture('01-actual-duo-outer-inicio');
      await tester.tap(find.byKey(const Key('bottom-nav-catalog')));
      await tester.pump(const Duration(seconds: 1));
      final category =
          find.byKey(const ValueKey('categories-category-crossbody'));
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0;
          i < 12 && find.byType(ProductCard).evaluate().isEmpty;
          i++) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -250),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }
      final card = find.byType(ProductCard).first;
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ProductScreen), findsOneWidget);
      final selected = tester.widget<ProductScreen>(find.byType(ProductScreen));
      var state = tester.state(find.byType(ProductScreen));
      final element = tester.element(find.byType(ProductScreen));
      final store = app.StoreScope.of(element);
      expect(
        app.CartScope.maybeOf(element),
        isNull,
        reason: 'offline configuration must not create a live Shopify cart',
      );
      final product =
          store.products.firstWhere((p) => p.id == selected.productId);
      final selector = find.byType(ProductOptionSelector);
      if (selectableVariants(product).length > 1) {
        tester.widget<ProductOptionSelector>(selector).onSelect(1);
        await tester.pump();
      }
      final selectedVariantId = selector.evaluate().isEmpty
          ? product.variants.first.id
          : selectedVariant(
              product,
              tester.widget<ProductOptionSelector>(selector).selectedIndex!,
            )!
              .id;
      if (product.images.length > 1) {
        await tester.tap(find.byKey(const Key('product-gallery-next')));
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester
              .widget<PageView>(find.byType(PageView).first)
              .controller
              ?.page
              ?.round(),
          1,
        );
      }
      await capture('02-actual-duo-outer-product');

      await waitPose(
        'open-landscape',
        (g) =>
            StorefrontLayout.canSplit(g.viewSize, TextScaler.noScaling) &&
            g.viewSize.width > g.viewSize.height &&
            g.divisions.every((r) => !r.active),
      );
      // The piece chosen on the outer display moves to the right side with
      // its state; the results fill the left side again.
      expect(tester.state(find.byType(ProductScreen)), same(state));
      final crease = geometry().divisions.first.bounds;
      expect(
        tester.getRect(find.byType(ProductScreen)).left,
        greaterThanOrEqualTo(crease.right - 1),
      );
      expect(find.byType(ProductCard).hitTestable(), findsWidgets);
      if (product.images.length > 1) {
        expect(
          tester
              .widget<PageView>(find.byType(PageView).first)
              .controller
              ?.page
              ?.round(),
          1,
        );
      }
      await capture('03-actual-duo-landscape-browse-detail');

      // Another piece previews on the right side, beside the results.
      final cards = find.byType(ProductCard).hitTestable();
      Finder? other;
      for (var i = 0; i < cards.evaluate().length; i++) {
        final candidate = cards.at(i);
        if (tester.widget<ProductCard>(candidate).product.id != product.id &&
            tester.getRect(candidate).right <= crease.left) {
          other = candidate;
          break;
        }
      }
      expect(other, isNotNull, reason: 'a second piece on the left side');
      await tester.tap(other!);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('duo-preview')), findsOneWidget);
      expect(find.byType(ProductCard).hitTestable(), findsWidgets);
      await capture('04-actual-duo-landscape-preview');

      // «VER PRODUCTO» opens the first piece on the right side again.
      final viewFirst = find.byKey(Key('view-product-${product.id}')).first;
      await tester.ensureVisible(viewFirst);
      await tester.pumpAndSettle();
      await tester.tap(viewFirst);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('duo-preview')), findsNothing);
      state = tester.state(find.byType(ProductScreen));
      if (selectableVariants(product).length > 1) {
        tester.widget<ProductOptionSelector>(selector).onSelect(1);
        await tester.pump();
      }
      await waitPose(
        'partial-fold',
        (g) => g.divisions.any((r) => r.active && !r.bounds.isEmpty),
      );
      expect(tester.state(find.byType(ProductScreen)), same(state));
      final primary = find.byKey(const Key('purchase-dock-primary'));
      await tester.ensureVisible(primary);
      await tester.pump(const Duration(seconds: 1));
      for (final r in [...geometry().divisions, ...geometry().occlusions]) {
        if (r.active) {
          expect(tester.getRect(primary).overlaps(r.bounds), isFalse);
        }
      }
      await capture('05-actual-duo-partial-fold-product');
      await waitPose('open-flat', (g) => g.divisions.every((r) => !r.active));
      expect(tester.state(find.byType(ProductScreen)), same(state));
      await waitPose(
        'inner-portrait',
        (g) =>
            g.viewSize.height > g.viewSize.width &&
            g.divisions.isNotEmpty &&
            g.barEdge == SystemBarEdge.none,
      );
      expect(tester.state(find.byType(ProductScreen)), same(state));
      await capture('06-actual-duo-inner-portrait-product');
      await waitPose(
        'closed-again',
        (g) => g.divisions.isEmpty && g.barEdge != SystemBarEdge.none,
      );
      expect(tester.state(find.byType(ProductScreen)), same(state));
      if (selector.evaluate().isNotEmpty) {
        expect(
          selectedVariant(
            product,
            tester.widget<ProductOptionSelector>(selector).selectedIndex!,
          )!
              .id,
          selectedVariantId,
        );
      }
      await tester.ensureVisible(primary);
      await tester.pumpAndSettle();
      expect(primary.hitTestable(), findsOneWidget);
      final before = store.bagQuantity;
      await tester.tap(primary);
      for (var i = 0;
          i < 20 && find.byType(MiniCartSheet).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(store.bagQuantity, before + 1);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bottom-nav-bag')));
      await tester.pumpAndSettle();
      await capture('07-actual-duo-outer-cart');
      debugPrint('DUO_STAGE:accessibility-text');
      for (var i = 0; i < 180; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (MediaQuery.textScalerOf(
              tester.element(find.byType(Scaffold).last),
            ).scale(16) >
            24) {
          break;
        }
      }
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(Scaffold).last),
        ).scale(16),
        greaterThan(24),
      );
      await tester.pumpAndSettle();
      await capture('08a-actual-duo-accessibility-cart-heading');
      await tester.ensureVisible(find.byTooltip('Agregar uno'));
      await tester.pumpAndSettle();
      await capture('08-actual-duo-accessibility-cart');
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );
}
