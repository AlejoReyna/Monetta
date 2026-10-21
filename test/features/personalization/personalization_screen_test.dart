import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/categories_screen.dart';
import 'package:monetta_app/features/personalization/personalization_screen.dart';
import 'package:monetta_app/features/personalization/shopper_preferences.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';

void main() {
  test('preferences round-trip and stay on their account', () async {
    final store = MemoryShopperPreferenceStore();
    const first = ShopperPreferences(
      brands: {'coach'},
      styles: {'crossbody', 'wallets'},
      purchaseType: ShopperPurchaseType.mayoreo,
    );
    await store.write('account-a', first);
    await store.write(
      'account-b',
      const ShopperPreferences(purchaseType: ShopperPurchaseType.menudeo),
    );

    final restored = await store.read('account-a');
    expect(restored.brands, {'coach'});
    expect(restored.styles, {'crossbody', 'wallets'});
    expect(restored.purchaseType, ShopperPurchaseType.mayoreo);
    expect(
      (await store.read('account-b')).purchaseType,
      ShopperPurchaseType.menudeo,
    );
    expect((await store.read('account-c')).brands, isEmpty);

    final edited = ShopperPreferences(
      brands: restored.brands.difference({'coach'}),
      styles: restored.styles,
      purchaseType: null,
    );
    await store.write('account-a', edited);
    expect((await store.read('account-a')).brands, isEmpty);
    expect((await store.read('account-a')).purchaseType, isNull);
  });

  testWidgets('saves, restores and edits preferences without changing prices',
      (tester) async {
    final db = openTestDatabase();
    final catalog = CatalogStore(database: db);
    addTearDown(() async {
      catalog.dispose();
      await db.close();
    });
    await catalog.loadFromAsset();
    final prices = [for (final product in catalog.products) product.price];
    final preferences = MemoryShopperPreferenceStore();
    final brand = catalog.availableBrands.first;

    Future<void> pump(String scope) {
      return pumpClientGuide(
        tester,
        StoreScope(
          notifier: catalog,
          child: PersonalizationScreen(
            store: preferences,
            scopeKey: scope,
          ),
        ),
        size: const Size(390, 1200),
      );
    }

    await pump('account-a');
    expect(find.text('Personalización'), findsOneWidget);
    expect(clientGuideCategories, hasLength(8));
    for (final style in clientGuideCategories) {
      expect(find.text(style.title), findsWidgets);
    }

    Future<void> tap(Key key) async {
      final finder = find.byKey(key);
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
    }

    await tap(ValueKey('personalization-brand-$brand'));
    await tap(const ValueKey('personalization-style-crossbody'));
    await tap(const ValueKey('personalization-style-wallets'));
    await tap(const ValueKey('personalization-purchase-mayoreo'));
    await tap(const ValueKey('personalization-save'));
    await tester.pumpAndSettle();

    final saved = await preferences.read('account-a');
    expect(saved.brands, {brand});
    expect(saved.styles, {'crossbody', 'wallets'});
    expect(saved.purchaseType, ShopperPurchaseType.mayoreo);
    expect([for (final product in catalog.products) product.price], prices);
    expect(catalog.profile.topOf('brand'), contains(brand));
    expect(catalog.profile.topOf('silhouette'), contains('crossbody'));
    expect(
      catalog.profile.weights.keys.any((key) => key.contains('mayoreo')),
      isFalse,
    );

    await pump('account-a');
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(
                    const ValueKey('personalization-purchase-mayoreo'),
                  ),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );

    await tap(ValueKey('personalization-brand-$brand'));
    await tap(const ValueKey('personalization-purchase-mayoreo'));
    await tap(const ValueKey('personalization-save'));
    await tester.pumpAndSettle();
    final edited = await preferences.read('account-a');
    expect(edited.brands, isEmpty);
    expect(edited.purchaseType, isNull);
    expect(edited.styles, {'crossbody', 'wallets'});

    await pump('account-b');
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(
                    const ValueKey('personalization-purchase-mayoreo'),
                  ),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isFalse,
    );
    expect([for (final product in catalog.products) product.price], prices);
  });

  for (final (size, brightness) in [
    (const Size(390, 2400), Brightness.light),
    (const Size(390, 2400), Brightness.dark),
    (const Size(834, 2400), Brightness.light),
  ]) {
    testWidgets('personalization capture ${size.width} ${brightness.name}',
        (tester) async {
      final db = openTestDatabase();
      final catalog = CatalogStore(database: db);
      addTearDown(() async {
        catalog.dispose();
        await db.close();
      });
      await catalog.loadFromAsset();
      await pumpClientGuide(
        tester,
        StoreScope(
          notifier: catalog,
          child: const PersonalizationScreen(
            store: _EmptyStore(),
            scopeKey: 'capture',
          ),
        ),
        size: size,
        brightness: brightness,
      );
      await captureClientGuide(
        tester,
        'personalization-${size.width.toInt()}-${brightness.name}',
      );
      expect(find.text('Guardar preferencias'), findsOneWidget);
    });
  }
}

class _EmptyStore implements ShopperPreferenceStore {
  const _EmptyStore();

  @override
  Future<ShopperPreferences> read(String accountId) async =>
      ShopperPreferences.empty;

  @override
  Future<void> write(String accountId, ShopperPreferences value) async {}
}
