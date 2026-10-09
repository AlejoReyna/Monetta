/// PERF-01 (ratchet): how many elements a store notification that does not
/// concern the screen makes each pilot screen rebuild.
///
/// Every pilot screen reads the store with `StoreScope.of(context)`, an
/// `InheritedNotifier`, so any `notifyListeners()` (R20: `CatalogStore.record`
/// notifies the whole tree) rebuilds them. The counts below are the baseline
/// measured before the ViewModels of RF-41; the work may only lower them.
///
/// Each case mounts the screen over the bundled asset catalog, settles it in
/// bounded frames, installs the counter and fires three events about a piece
/// the screen is not showing, pumping one frame after each. Only those three
/// frames are counted. A control frame without a notification is measured too,
/// so animation noise (shimmers, carousels) can be told apart from the cost of
/// the notification.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/reco/events.dart';

import '../../support/product_screen_harness.dart' show mockPathProvider;
import '../../support/rebuild_counter.dart';

/// Notifications fired per case.
const int _kNotifications = 3;

/// The in-stock asset product with the longest title (as UI-03 does).
Product _longestInStock(Iterable<Product> products) {
  final inStock = products.where((p) => p.isInStock).toList()
    ..sort((a, b) => b.title.length.compareTo(a.title.length));
  return inStock.first;
}

/// Mounts [build] over the asset catalog, settles it, then measures.
///
/// [baselineTotal] and [baselineOwn] are the ceilings for the three
/// notifications; [other] picks the piece the events are about.
void _measure(
  String screenName,
  Widget Function(CatalogStore store) build, {
  required Type screenType,
  required Finder Function() anchor,
  required int baselineTotal,
  required int baselineOwn,
  Product Function(CatalogStore store)? other,
}) {
  testWidgets(
      'PERF-01 $screenName rebuilds on a notification that does '
      'not concern it', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(375, 812) * 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    mockPathProvider();

    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(theme: buildLightTheme(), home: build(store)),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      anchor(),
      findsWidgets,
      reason: 'PERF-01 $screenName: the screen did not paint its content.',
    );
    final screen = tester.element(find.byType(screenType));

    final counter = RebuildCounter(screen);
    addTearDown(counter.stop);

    // Control: one frame with no notification.
    counter.start();
    await tester.pump();
    final controlTotal = counter.total;
    final controlOwn = counter.own;

    final piece = (other ?? _lastPiece)(store);
    counter.start();
    for (var i = 0; i < _kNotifications; i++) {
      store.record(EventType.galleryInteraction, productId: piece.id);
      await tester.pump();
    }
    counter.stop();

    debugPrint(
      'PERF-01 $screenName: total=${counter.total} own=${counter.own} '
      '(control frame without notification: total=$controlTotal '
      'own=$controlOwn)',
    );

    expect(
      counter.total,
      lessThanOrEqualTo(baselineTotal),
      reason: '$screenName rebuilt more elements than the baseline.',
    );
    expect(
      counter.own,
      lessThanOrEqualTo(baselineOwn),
      reason: '$screenName rebuilt its own element more than the baseline.',
    );
  });
}

/// At least one product card: proves the grid really holds products.
Finder _productCards() => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('product-card-');
    });

Product _lastPiece(CatalogStore store) => store.products.last;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _measure(
    'SearchScreen',
    (store) => SearchScreen(
      initialQuery: 'Michael Kors',
      prompt: 'Encuentra algo muy tú',
      history: SearchHistory(),
    ),
    screenType: SearchScreen,
    anchor: () => _productCards(),
    // RF-41 baseline 2026-10-09; lower it when the count drops.
    // 939 / 3 before the SearchViewModel; the cards still read the store.
    baselineTotal: 411,
    baselineOwn: 0,
  );

  _measure(
    'CollectionScreen',
    (store) => const CollectionScreen(
      title: 'Bolsas',
      filter: CollectionFilter(category: 'bolsa'),
    ),
    screenType: CollectionScreen,
    anchor: () => _productCards(),
    // RF-41 baseline 2026-10-09; lower it when the count drops.
    baselineTotal: 1044,
    baselineOwn: 3,
  );

  _measure(
    'CatalogBrowseScreen',
    (store) => CatalogBrowseScreen(
      products: store.products,
      facetsById: store.facetsById,
      bagCount: store.bagQuantity,
    ),
    screenType: CatalogBrowseScreen,
    anchor: () => find.byKey(const Key('catalog-filter-button')),
    // RF-41 baseline 2026-10-09; lower it when the count drops.
    baselineTotal: 3,
    baselineOwn: 0,
  );

  _measure(
    'ProductScreen',
    (store) => ProductScreen(productId: _longestInStock(store.products).id),
    screenType: ProductScreen,
    anchor: () => find.byKey(const Key('purchase-dock-primary')),
    // RF-41 baseline 2026-10-09; lower it when the count drops.
    baselineTotal: 1413,
    baselineOwn: 3,
    other: (store) {
      final shown = _longestInStock(store.products).id;
      return store.products.lastWhere((p) => p.id != shown);
    },
  );
}
