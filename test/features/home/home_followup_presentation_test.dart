import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/normalize/normalizer.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';
import 'package:monetta_app/main.dart';
import '../../support/client_guide_capture.dart';

void main() {
  for (final (size, scale, brightness) in [
    (const Size(390, 1100), 1.0, Brightness.light),
    (const Size(320, 568), 2.0, Brightness.light),
    (const Size(834, 1194), 1.0, Brightness.light),
    (const Size(390, 1100), 1.0, Brightness.dark),
  ]) {
    testWidgets('follow-up actions and footer at $size / $scale / $brightness',
        (tester) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      await store.loadFromAsset();
      // Evidence carries synthetic merchandise only, with no remote images.
      store.products = [
        Product(
          id: 'demo-bag',
          handle: 'demo-bag',
          title: 'Bolsa de demostración',
          vendor: 'Demo',
          productType: 'bolsa',
          tags: const [],
          variants: const [
            ProductVariant(
              id: 'demo-variant',
              title: 'Default Title',
              price: 100,
              available: true,
            ),
          ],
          images: const [],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ];
      store.facetsById = {
        for (final product in store.products)
          product.id: Normalizer(store.rules)
              .normalize(product, now: DateTime.utc(2026)),
      };
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await pumpClientGuide(
        tester,
        StoreScope(notifier: store, child: const HomeScreen()),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      final scroll = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;
      final banner = find.byKey(const ValueKey('home-wholesale-button'));
      await tester.scrollUntilVisible(banner, 500, scrollable: scroll);
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('home-section-offers'))),
        alignment: .15,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('mínimo de piezas: pendientes'),
        findsOneWidget,
      );
      if (scale == 1) {
        await captureClientGuide(
          tester,
          'home-followup-${size.width.toInt()}-${brightness.name}',
        );
      }
      if (scale == 1) {
        await tester.ensureVisible(banner);
        await tester.pumpAndSettle();
        await tester.tap(banner);
        await tester.pumpAndSettle();
        expect(find.byType(WholesaleScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('client-guide-footer')),
        400,
        scrollable: scroll,
      );
      await tester
          .ensureVisible(find.text('Monetta · Todos los derechos reservados'));
      await tester.pumpAndSettle();
      expect(find.text('Ayuda y contacto'), findsOneWidget);
      if (scale == 1) {
        await captureClientGuide(
          tester,
          'home-footer-${size.width.toInt()}-${brightness.name}',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
