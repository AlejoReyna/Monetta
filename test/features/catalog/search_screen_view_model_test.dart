/// RF-41: how `SearchScreen` owns its ViewModel (lifecycle, not rendering;
/// rendering is pinned by `search_screen_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/product_screen_harness.dart' show mockPathProvider;

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

class _CountingHistory extends SearchHistory {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStore store;

  setUp(() async {
    mockPathProvider();
    store = _CountingStore(database: openTestDatabase());
    await store.loadFromAsset();
  });

  tearDown(() => store.dispose());

  testWidgets('RF-41 SearchScreen releases its listeners when it is removed',
      (tester) async {
    final history = _CountingHistory();
    final storeBefore = store.listeners;

    await tester.pumpWidget(
      _app(
        store,
        SearchScreen(prompt: 'Buscar', history: history),
      ),
    );
    // The StoreScope inherited notifier is a listener of its own.
    expect(store.listeners, greaterThan(storeBefore));
    expect(history.listeners, 1);

    await tester.pumpWidget(_app(store, null));

    expect(history.listeners, 0, reason: 'no dangling history listener');
    expect(
      store.listeners,
      storeBefore + 1,
      reason: 'only the StoreScope itself still listens to the store',
    );
  });

  testWidgets(
      'RF-41 SearchScreen keeps its query and history when rebuilt with other '
      'parameters', (tester) async {
    final first = _CountingHistory();
    final second = _CountingHistory();

    await tester.pumpWidget(
      _app(
        store,
        SearchScreen(initialQuery: 'coach', prompt: 'Uno', history: first),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('search-result-grid')), findsOneWidget);

    await tester.pumpWidget(
      _app(
        store,
        SearchScreen(initialQuery: 'guess', prompt: 'Dos', history: second),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('search-query-field')),
    );
    expect(field.controller!.text, 'coach');
    expect(find.byKey(const ValueKey('search-result-grid')), findsOneWidget);
    expect(first.listeners, 1, reason: 'still bound to the first history');
    expect(second.listeners, 0, reason: 'the new history is not adopted');
  });
}
