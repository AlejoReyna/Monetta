import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/catalog/catalog_query.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Widget _app(
  CatalogStore store, {
  SearchHistory? history,
  AccountController? account,
  AdminController? admin,
}) {
  Widget child = StoreScope(
    notifier: store,
    child: SearchScreen(
      prompt: 'Encuentra algo muy tú',
      history: history ?? SearchHistory(),
    ),
  );
  if (account != null) child = AccountScope(notifier: account, child: child);
  if (admin != null) child = AdminScope(notifier: admin, child: child);
  return MaterialApp(theme: buildTheme(), home: child);
}

/// A signed-in account on the owner allow-list, with the admin state that
/// recognises it: the only viewer for whom the result count renders.
(AccountController, AdminController) _owner(AppDatabase db) {
  const email = 'owner@example.com';
  final account = AccountController(
    accountStore: AccountStore(db),
    deviceStore: DeviceStore(db),
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    deviceId: 'dev-1',
  )..account = Account(
      localAccountId: 'acct-owner',
      email: email,
      authProvider: 'monetta',
      createdAt: DateTime.utc(2026),
      lastSeenAt: DateTime.utc(2026),
    );
  final admin = AdminController(
    config: const AdminConfig(baseUrl: null, ownerEmails: {email}),
  );
  return (account, admin);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const ValueKey('search-query-field')),
    text,
  );
  await tester.pump();
}

void main() {
  test('search invitations have five distinct prompts', () {
    expect(kSearchPrompts, hasLength(5));
    expect(kSearchPrompts.toSet(), hasLength(5));
  });

  testWidgets('typing offers catalog suggestions and submitting shows results',
      (tester) async {
    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.byKey(const ValueKey('search-query-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-empty-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-suggestions')), findsNothing);
    expect(find.byKey(const ValueKey('search-result-grid')), findsNothing);

    await _type(tester, 'steve');

    expect(find.byKey(const ValueKey('search-suggestions')), findsOneWidget);
    expect(find.text('Steve Madden', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('search-result-grid')), findsNothing);

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('search-suggestions')),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-result-grid')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-clear-button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('search-empty-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-suggestions')), findsNothing);
    expect(find.byKey(const ValueKey('search-result-grid')), findsNothing);
  });

  testWidgets('an empty query offers categories and a product selection',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    // Only categories the catalog really has, and no empty section headings.
    expect(find.byKey(const ValueKey('search-category-bolsa')), findsOneWidget);
    expect(find.text('Sugerencias'), findsOneWidget);
    expect(find.text('Productos'), findsOneWidget);
    expect(find.byKey(const ValueKey('search-product-rail')), findsOneWidget);
    expect(find.text('Búsquedas recientes'), findsNothing);
  });

  testWidgets('a category opens a real collection, not a dead end',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('search-category-bolsa')));
    await tester.pumpAndSettle();

    expect(find.byType(CollectionScreen), findsOneWidget);
  });

  testWidgets('a submitted query is remembered, reusable and removable',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final history = SearchHistory();
    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store, history: history));
    await tester.pump();

    await _type(tester, 'coach');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-result-grid')), findsOneWidget);
    expect(history.queries, ['coach']);

    // Typing alone must never be recorded — only a submitted query.
    await tester.tap(find.byKey(const ValueKey('search-clear-button')));
    await tester.pump();
    await _type(tester, 'guess');
    expect(history.queries, ['coach']);

    await tester.tap(find.byKey(const ValueKey('search-clear-button')));
    await tester.pump();
    expect(find.text('Búsquedas recientes'), findsOneWidget);
    expect(find.byKey(const ValueKey('search-history-coach')), findsOneWidget);

    // Re-running a recent search brings its results back.
    await tester.tap(find.byKey(const ValueKey('search-history-coach')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-result-grid')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-clear-button')));
    await tester.pump();
    await tester.tap(find.byTooltip('Quitar “coach” del historial'));
    await tester.pumpAndSettle();
    expect(history.queries, isEmpty);
    expect(find.text('Búsquedas recientes'), findsNothing);
  });

  testWidgets('the whole history can be cleared', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final history = SearchHistory();
    await history.remember('bolso coach');
    await history.remember('reloj guess');

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store, history: history));
    await tester.pump();

    expect(find.byKey(const ValueKey('search-history-clear')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('search-history-clear')));
    await tester.pumpAndSettle();

    expect(history.isEmpty, isTrue);
    expect(find.text('Búsquedas recientes'), findsNothing);
  });

  testWidgets('no results names the term and offers real categories',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await _type(tester, 'zzzzqq');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-no-results')), findsOneWidget);
    expect(find.textContaining('zzzzqq'), findsWidgets);
    expect(
      find.byKey(const ValueKey('search-no-results-category-bolsa')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('search-no-results-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-empty-state')), findsOneWidget);
  });

  testWidgets('the query survives coming back from another route',
      (tester) async {
    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await _type(tester, 'coach');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('otra ruta')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('otra ruta'), findsOneWidget);

    navigator.pop();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('search-query-field')))
          .controller
          ?.text,
      'coach',
    );
    expect(find.byKey(const ValueKey('search-result-grid')), findsOneWidget);
  });

  testWidgets('for an owner, the result count matches the grid it labels',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    final db = openTestDatabase();
    addTearDown(db.close);
    final (account, admin) = _owner(db);
    addTearDown(account.dispose);
    addTearDown(admin.dispose);
    await tester.pumpWidget(_app(store, account: account, admin: admin));
    await tester.pump();

    await _type(tester, 'coach');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final expected = searchProducts(store, 'coach').length;
    expect(expected, greaterThan(0));
    expect(
      find.text(expected == 1 ? '1 pieza' : '$expected piezas'),
      findsOneWidget,
    );
  });

  testWidgets('a shopper sees results without a piece count', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await _type(tester, 'coach');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final expected = searchProducts(store, 'coach').length;
    expect(find.byKey(const ValueKey('search-result-grid')), findsOneWidget);
    expect(
      find.text(expected == 1 ? '1 pieza' : '$expected piezas'),
      findsNothing,
    );
  });
}
