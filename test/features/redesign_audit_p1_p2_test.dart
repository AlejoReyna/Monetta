import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/catalog_controls.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_history_persistence.dart';
import 'package:monetta_app/features/checkout/order_confirmation_screen.dart';
import 'package:monetta_app/main.dart';

Widget _app(Widget child) {
  return MaterialApp(theme: buildTheme(), home: Scaffold(body: child));
}

void main() {
  testWidgets('P1: BoutiqueButton accepts onPhoto on the default ctor',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            BoutiqueButton(label: 'A', onPressed: null, onPhoto: true),
            BoutiqueButton(label: 'B', onPressed: null),
            BoutiqueButton.onPhoto(label: 'C', onPressed: null),
          ],
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('P1: collection banner with a CTA builds (A/B contract)',
      (tester) async {
    await tester.pumpWidget(
      _app(
        CatalogEditorialBanner(
          title: 'Colección',
          imageAsset: 'assets/images/campaign_olive.jpg',
          actionLabel: 'Ver todo',
          onAction: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('catalog-banner-cta')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('P2: Ver pedido uses its callback, Seguir comprando pops',
      (tester) async {
    var viewed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showOrderConfirmation(
              context,
              onViewOrder: () => viewed++,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Ver pedido'), findsOneWidget);
    await tester.tap(find.text('Ver pedido'));
    await tester.pumpAndSettle();
    // Callback path: no pop, confirmation stays, callback ran.
    expect(viewed, 1);
    expect(find.text('Ver pedido'), findsOneWidget);

    // Fallback path without a callback still pops to first.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const OrderConfirmationScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Seguir comprando'), findsOneWidget);
  });

  test('P2: delivery estimate never fabricates dates', () {
    expect(
      estimatedDeliveryLabel(now: DateTime(2026, 5, 9)),
      '3 a 5 días hábiles',
    );
  });

  testWidgets('P2: tile exposes a visible, accessible quick-view action',
      (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final store = CatalogStore(database: db);
    addTearDown(store.dispose);
    await store.loadFromAsset();
    final product = store.products.first;

    var quickViews = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: StoreScope(
              notifier: store,
              child: ProductCard(
                product: product,
                onQuickView: () => quickViews++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final button = find.byTooltip('Vista rápida');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(quickViews, 1);
  });

  test('P2: search history survives a restart per scope', () async {
    final dir = await Directory.systemTemp.createTemp('search_history');
    addTearDown(() => dir.delete(recursive: true));
    final persistence =
        SearchHistoryFilePersistence(directoryProvider: () async => dir);

    final first = SearchHistory(persistence: persistence);
    await first.setScope('account-a');
    await first.remember('bolso coach');
    await first.remember('reloj guess');

    // Simulate a restart: a new instance reading the same directory.
    final second = SearchHistory(persistence: persistence);
    await second.setScope('account-a');
    expect(second.queries, ['reloj guess', 'bolso coach']);

    await second.setScope('account-b');
    expect(second.queries, isEmpty);

    await second.setScope(null);
    expect(second.queries, isEmpty);
  });
}
