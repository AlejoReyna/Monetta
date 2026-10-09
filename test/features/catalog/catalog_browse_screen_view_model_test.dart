/// RF-41: how `CatalogBrowseScreen` owns its ViewModel (lifecycle, rebuilds
/// and what new inputs do; rendering is pinned by
/// `catalog_browse_screen_test.dart` and the bag counter by CHAR-17).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/composition/app_scopes.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/reco/events.dart';

import '../../support/catalog_browse_fixtures.dart';
import '../../support/product_screen_harness.dart' show mockPathProvider;
import '../../support/rebuild_counter.dart';

class _CountingStore extends CatalogStore {
  _CountingStore({required super.database});

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

Widget _app(_CountingStore store, Widget? screen) => StoreScope(
      notifier: store,
      child: MaterialApp(
        theme: buildLightTheme(),
        home: screen ?? const SizedBox.shrink(),
      ),
    );

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Opens the sheet, marks the category [category] and applies.
Future<void> _applyCategory(WidgetTester tester, String category) async {
  await _tapVisible(tester, find.byKey(const Key('catalog-filter-button')));
  await _tapVisible(
    tester,
    find.byKey(const Key('catalog-filter-section-category')),
  );
  await _tapVisible(
    tester,
    find.byKey(Key('catalog-filter-category-$category')),
  );
  await _tapVisible(tester, find.byKey(const Key('catalog-filter-apply')));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStore store;

  setUp(() async {
    mockPathProvider();
    store = _CountingStore(database: openTestDatabase());
    await store.loadFromAsset();
  });

  tearDown(() => store.dispose());

  void useTallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
      'RF-41 CatalogBrowseScreen releases its listeners when it is removed',
      (tester) async {
    final storeBefore = store.listeners;

    await tester.pumpWidget(
      _app(
        store,
        CatalogBrowseScreen(
          products: store.products,
          facetsById: store.facetsById,
        ),
      ),
    );
    // The StoreScope inherited notifier is a listener of its own.
    expect(store.listeners, greaterThan(storeBefore + 1));

    await tester.pumpWidget(_app(store, null));

    expect(
      store.listeners,
      storeBefore + 1,
      reason: 'only the StoreScope itself still listens to the store',
    );
  });

  testWidgets(
      'RF-41 CatalogBrowseScreen does not rebuild itself for a notification '
      'that does not concern it', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(375, 812) * 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        store,
        CatalogBrowseScreen(
          products: store.products,
          facetsById: store.facetsById,
        ),
      ),
    );
    await tester.pump();
    final counter = RebuildCounter(
      tester.element(find.byType(CatalogBrowseScreen)),
    )..start();
    addTearDown(counter.stop);

    store.record(
      EventType.galleryInteraction,
      productId: store.products.last.id,
    );
    await tester.pump();
    counter.stop();

    expect(counter.own, 0);
  });

  testWidgets(
      'RF-41 CatalogBrowseScreen keeps the applied filters when rebuilt with '
      'other products', (tester) async {
    useTallPhone(tester);
    final first = [
      browseEntry(1, title: 'Cartera Uno', category: 'cartera'),
      browseEntry(2, title: 'Reloj Uno', category: 'reloj'),
    ];
    final second = [
      browseEntry(3, title: 'Cartera Dos', category: 'cartera'),
      browseEntry(4, title: 'Reloj Dos', category: 'reloj'),
      browseEntry(5, title: 'Cartera Tres', category: 'cartera'),
    ];

    await tester.pumpWidget(
      MaterialApp(theme: buildLightTheme(), home: browseScreen(first)),
    );
    await tester.pumpAndSettle();
    await _applyCategory(tester, 'cartera');
    expect(find.text('Cartera Uno'), findsOneWidget);
    expect(find.text('Reloj Uno'), findsNothing);
    expect(find.byKey(const Key('catalog-filter-count')), findsOneWidget);

    // Same State, other products: the filters stay, the grid follows.
    await tester.pumpWidget(
      MaterialApp(theme: buildLightTheme(), home: browseScreen(second)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cartera Dos'), findsOneWidget);
    expect(find.text('Cartera Tres'), findsOneWidget);
    expect(find.text('Reloj Dos'), findsNothing);
    expect(find.text('Cartera Uno'), findsNothing);
    expect(find.byKey(const Key('catalog-filter-count')), findsOneWidget);
  });

  testWidgets(
      'RF-41 CatalogBrowseScreen resets the filters from its empty '
      'state', (tester) async {
    useTallPhone(tester);
    final entries = [
      browseEntry(1, title: 'Cartera Uno', category: 'cartera'),
      browseEntry(2, title: 'Reloj Uno', category: 'reloj'),
    ];

    await tester.pumpWidget(
      MaterialApp(theme: buildLightTheme(), home: browseScreen(entries)),
    );
    await tester.pumpAndSettle();
    await _applyCategory(tester, 'cartera');
    expect(find.byKey(const Key('catalog-filter-count')), findsOneWidget);

    // New products with nothing in the applied category: the empty state.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: browseScreen([
          browseEntry(9, title: 'Reloj Solo', category: 'reloj'),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reloj Solo'), findsNothing);
    final reset = find.text('Limpiar filtros');
    expect(reset, findsOneWidget);
    await tester.tap(reset);
    await tester.pumpAndSettle();

    expect(find.text('Reloj Solo'), findsOneWidget);
    expect(find.byKey(const Key('catalog-filter-count')), findsNothing);
  });
}
