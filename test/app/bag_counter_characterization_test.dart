/// CHAR-05: objective behaviour of the bag counter (RF-53, E4).
///
/// `CatalogStore.bagQuantity` counts only the units of visible lines; lines
/// whose product or exact variant is not in the catalog are hidden from the
/// counter (and were already hidden from `bagLines` and `bagSubtotal`). The
/// bag screen announces the hidden lines with the E4 notice and offers their
/// explicit removal; a listed but sold-out line keeps counting and is marked
/// `Agotado` (a separate notice from the unavailable one, per E4 details).
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

const _notice =
    'Algunos artículos ya no están disponibles y no se incluyeron en tu bolsa';
const _removeUnavailable = 'Retirar no disponibles';
const _soldOut = 'Agotado';

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

/// The visible product with its first variant marked sold out.
Product _soldOutCopy(Product visible) {
  final variant = visible.variants.first;
  return Product(
    id: visible.id,
    handle: visible.handle,
    title: visible.title,
    vendor: visible.vendor,
    productType: visible.productType,
    tags: visible.tags,
    variants: [
      ProductVariant(
        id: variant.id,
        title: variant.title,
        price: variant.price,
        available: false,
        compareAtPrice: variant.compareAtPrice,
        sku: variant.sku,
      ),
      ...visible.variants.skip(1),
    ],
    images: visible.images,
    createdAt: visible.createdAt,
    updatedAt: visible.updatedAt,
    descriptionHtml: visible.descriptionHtml,
    collectionHandles: visible.collectionHandles,
    brandOverride: visible.brandOverride,
    categoryOverride: visible.categoryOverride,
  );
}

Future<void> _pumpBagScreen(WidgetTester tester, CatalogStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: const Scaffold(body: BagScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'CHAR-05 (RF-53, E4) bagQuantity counts only the visible line; '
      'bagLines and bagSubtotal are unchanged', () async {
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

    expect(store.bagQuantity, _visibleQuantity);
    expect(
      store.bagSubtotal,
      fixture.visibleVariant.price * _visibleQuantity,
      reason: 'the subtotal only counts the visible line',
    );

    await pumpEventQueue();
    store.dispose();
  });

  testWidgets('CHAR-05 (RF-53, E4) BagAction announces only the visible units',
      (tester) async {
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
      find.byTooltip('Mi bolsa, $_visibleQuantity artículos'),
      findsOneWidget,
    );
    expect(find.byTooltip('Mi bolsa'), findsNothing);
    expect(store.bagLines, hasLength(1));
    expect(find.text('$_visibleQuantity'), findsOneWidget);
  });

  test(
      'CHAR-05 (RF-53, E4) when the product leaves the catalog its line '
      'leaves the counter too', () async {
    final fixture = await _startWithThreeLines();
    final store = fixture.store;
    expect(store.bagLines, hasLength(1));

    store.products = [
      for (final product in store.products)
        if (product.id != fixture.visible.id) product,
    ];

    expect(store.bagLines, isEmpty);
    expect(store.bagSubtotal, 0);
    expect(store.bagQuantity, 0);

    await pumpEventQueue();
    store.dispose();
  });

  testWidgets(
      'CHAR-05 (RF-53, E4) the bag screen announces the hidden lines and '
      'their removal clears them', (tester) async {
    final fixture = await _startWithThreeLines();
    final store = fixture.store;
    addTearDown(store.dispose);
    // The counter itself is pinned by the cases above; here the red reason
    // must be the missing notice, so no counter precondition.

    await _pumpBagScreen(tester, store);

    expect(find.text(_notice), findsOneWidget);
    expect(find.text(_removeUnavailable), findsOneWidget);

    await tester.tap(find.text(_removeUnavailable));
    await tester.pumpAndSettle();

    expect(find.text(_notice), findsNothing);
    expect(
      (await BagStore(fixture.db).all()).map((row) => row.variantId),
      [fixture.visibleVariant.id],
      reason: 'only the hidden lines are removed',
    );
    expect(store.bagQuantity, _visibleQuantity);
  });

  testWidgets(
      'CHAR-05 (RF-53, E4) a listed but sold-out line still counts and is '
      'marked Agotado', (tester) async {
    // Minimal bag with a single line and nothing hidden, so no notice shows.
    final probe = CatalogStore(database: openTestDatabase());
    await probe.loadFromAsset();
    final visible =
        probe.products.firstWhere((product) => product.variants.isNotEmpty);
    await probe.syncWithShopify();
    probe.dispose();

    final db = openTestDatabase();
    await BagStore(db).upsert(
      productId: visible.id,
      variantId: visible.variants.first.id,
      quantity: _visibleQuantity,
    );
    final store = CatalogStore(database: db);
    await store.loadFromAsset();
    await store.syncWithShopify();
    addTearDown(store.dispose);

    store.products = [
      for (final product in store.products)
        if (product.id == visible.id) _soldOutCopy(product) else product,
    ];
    await tester.pump();
    expect(store.bagLines, hasLength(1));
    expect(
      store.bagQuantity,
      _visibleQuantity,
      reason: 'a listed line counts even without stock',
    );

    await _pumpBagScreen(tester, store);

    expect(find.text(_soldOut), findsOneWidget);
    expect(find.text(_notice), findsNothing);
  });
}
