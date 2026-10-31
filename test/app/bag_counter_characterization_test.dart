/// CHAR-05: characterization of the bag counter.
///
/// `CatalogStore.bagQuantity` sums every quantity loaded from the database,
/// including lines whose product or exact variant is not in the catalog, while
/// `bagLines` and `bagSubtotal` only see the visible ones. So the badge can
/// promise more items than the bag screen lists. RF-50 (E4: count only visible
/// lines) has to change these tests explicitly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/main.dart';

const _ghostProductId = 'gid://shopify/Product/ghost';
const _ghostVariantId = 'gid://shopify/ProductVariant/ghost';
const _missingVariantId = 'gid://shopify/ProductVariant/missing';

const _visibleQuantity = 2;
const _ghostQuantity = 4;
const _missingVariantQuantity = 5;
const _totalQuantity =
    _visibleQuantity + _ghostQuantity + _missingVariantQuantity;

class _Fixture {
  _Fixture(this.db, this.store, this.visible, this.withMissingVariant);

  final AppDatabase db;
  final CatalogStore store;

  /// Product and exact variant that exist in the catalog.
  final Product visible;

  /// A catalog product whose persisted bag line points at a variant that does
  /// not exist on it.
  final Product withMissingVariant;

  ProductVariant get visibleVariant => visible.variants.first;
}

/// Persists three lines in the guest scope, then starts the store so that
/// `loadFromAsset()` hydrates them:
/// - one visible (catalog product and exact variant),
/// - one whose product is not in the catalog,
/// - one whose product is present but whose variant does not exist.
Future<_Fixture> _startWithThreeLines() async {
  // Discover two real asset products without touching the database under test.
  final probe = CatalogStore(database: openTestDatabase());
  await probe.loadFromAsset();
  final candidates =
      probe.products.where((product) => product.variants.isNotEmpty).toList();
  final visible = candidates[0];
  final withMissingVariant = candidates[1];
  await probe.syncWithShopify();
  probe.dispose();

  final db = openTestDatabase();
  final bag = BagStore(db);
  await bag.upsert(
    productId: visible.id,
    variantId: visible.variants.first.id,
    quantity: _visibleQuantity,
  );
  await bag.upsert(
    productId: _ghostProductId,
    variantId: _ghostVariantId,
    quantity: _ghostQuantity,
  );
  await bag.upsert(
    productId: withMissingVariant.id,
    variantId: _missingVariantId,
    quantity: _missingVariantQuantity,
  );

  // No configured shop: with one, a bag persisted before any catalog
  // provenance exists would be wiped by the shop reset (see CHAR-03).
  final store = CatalogStore(database: db);
  await store.loadFromAsset();
  await store.syncWithShopify();
  return _Fixture(db, store, visible, withMissingVariant);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'CHAR-05 (vigente, cambia según E4) bagQuantity suma también las '
      'líneas invisibles; bagLines y bagSubtotal sólo ven la visible',
      () async {
    final fixture = await _startWithThreeLines();
    final store = fixture.store;

    expect(
      await BagStore(fixture.db).all(),
      hasLength(3),
      reason: 'all three lines are persisted',
    );

    expect(store.bagLines, hasLength(1));
    final line = store.bagLines.single;
    expect(line.product.id, fixture.visible.id);
    expect(line.variant.id, fixture.visibleVariant.id);
    expect(line.quantity, _visibleQuantity);

    expect(store.bagQuantity, _totalQuantity);
    expect(
      store.bagSubtotal,
      fixture.visibleVariant.price * _visibleQuantity,
      reason: 'the subtotal only counts the visible line',
    );

    await pumpEventQueue();
    store.dispose();
  });

  testWidgets(
      'CHAR-05 (vigente, cambia según E4) BagAction anuncia la suma de las '
      'tres líneas aunque sólo una sea visible', (tester) async {
    final fixture = await _startWithThreeLines();
    final store = fixture.store;
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: Scaffold(
            appBar: AppBar(actions: const [BagAction()]),
          ),
        ),
      ),
    );

    expect(
      find.byTooltip('Mi bolsa, $_totalQuantity artículos'),
      findsOneWidget,
    );
    expect(find.byTooltip('Mi bolsa'), findsNothing);
    expect(store.bagLines, hasLength(1));
    // The badge caps its label at nine.
    expect(find.text('9+'), findsOneWidget);
  });

  test(
      'CHAR-05 (vigente, cambia según E4) si el producto sale del catálogo '
      'su línea deja de verse pero sigue contando en bagQuantity', () async {
    final fixture = await _startWithThreeLines();
    final store = fixture.store;
    expect(store.bagLines, hasLength(1));

    store.products = [
      for (final product in store.products)
        if (product.id != fixture.visible.id) product,
    ];

    expect(store.bagLines, isEmpty);
    expect(store.bagSubtotal, 0);
    expect(store.bagQuantity, _totalQuantity);

    await pumpEventQueue();
    store.dispose();
  });
}
