import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';
import '../../support/product_screen_harness.dart';

void main() {
  setUpAll(mockPathProvider);

  for (final (size, brightness) in [
    (const Size(390, 844), Brightness.light),
    (const Size(390, 844), Brightness.dark),
    (const Size(834, 1194), Brightness.light),
  ]) {
    testWidgets(
      'predictive search at ${size.width.toInt()} / ${brightness.name}',
      (tester) async {
        final db = openTestDatabase();
        final store = CatalogStore(database: db);
        await store.loadFromAsset();
        // Network photography is unavailable inside widget tests; empty
        // images render the deterministic boutique fallback instead of
        // starting flutter_cache_manager's sqflite path.
        store.products = [
          for (final product in store.products)
            Product(
              id: product.id,
              handle: product.handle,
              title: product.title,
              vendor: product.vendor,
              productType: product.productType,
              tags: product.tags,
              variants: product.variants,
              images: const [],
              createdAt: product.createdAt,
              updatedAt: product.updatedAt,
              descriptionHtml: product.descriptionHtml,
              collectionHandles: product.collectionHandles,
              brandOverride: product.brandOverride,
              categoryOverride: product.categoryOverride,
            ),
        ];
        final history = SearchHistory();
        await history.remember('bolso coach negro');
        await history.remember('cartera michael kors');
        await history.remember('reloj guess');
        addTearDown(() async {
          store.dispose();
          await db.close();
        });

        await pumpClientGuide(
          tester,
          StoreScope(
            notifier: store,
            child: SearchScreen(
              prompt: 'Encuentra algo muy tú',
              history: history,
            ),
          ),
          size: size,
          brightness: brightness,
        );
        await tester.enterText(
          find.byKey(const ValueKey('search-query-field')),
          'coach',
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('search-predictive')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('search-product-rail')),
          findsOneWidget,
        );
        if (size.width == 390) {
          await captureClientGuide(
            tester,
            'search-predictive-${size.width.toInt()}-${brightness.name}',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty predictive state at 320 / 200%', (tester) async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    await store.loadFromAsset();
    addTearDown(() async {
      store.dispose();
      await db.close();
    });

    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: SearchScreen(history: SearchHistory()),
      ),
      size: const Size(320, 568),
      textScale: 2,
    );
    await tester.enterText(
      find.byKey(const ValueKey('search-query-field')),
      'zzzzqq',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('search-predictive-empty')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
