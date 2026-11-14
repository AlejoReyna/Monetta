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
import 'package:monetta_app/domain/product.dart';

import '../support/product_screen_harness.dart';
import '../support/quick_add_harness.dart';

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

  testWidgets(
      'P2: Ver detalles del pedido uses its callback, Volver al inicio pops',
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

    expect(find.text('Ver detalles del pedido'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver detalles del pedido'));
    await tester.tap(find.text('Ver detalles del pedido'));
    await tester.pumpAndSettle();
    // Callback path: no pop, confirmation stays, callback ran.
    expect(viewed, 1);
    expect(find.text('Ver detalles del pedido'), findsOneWidget);

    // Fallback path without a callback still pops to first.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const OrderConfirmationScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Volver al inicio'), findsOneWidget);
  });

  test('P2: delivery estimate never fabricates dates', () {
    expect(
      estimatedDeliveryLabel(now: DateTime(2026, 5, 9)),
      '3 a 5 días hábiles',
    );
  });

  // The card is its own accessible action since the card redesign: tapping it
  // (photo or text) opens the quick view, a long press calls `onQuickView`,
  // the heart keeps its 48 px zone and the «VER PRODUCTO» pill is the way to
  // the product page. No "+" and no corner eye are drawn.
  testWidgets(
      'P2: the card is a labelled, hinted button that opens the quick '
      'view', (tester) async {
    mockPathProvider();
    final db = openTestDatabase();
    addTearDown(db.close);
    final store = CatalogStore(database: db);
    addTearDown(store.dispose);
    await store.loadFromAsset();
    final soldOut = soldOutProduct();
    addProducts(store, [soldOut]);
    final product = singleVariantAssetProduct(store);

    Future<void> mount(Product piece, VoidCallback onQuickView) async {
      await tester.pumpWidget(
        fichaApp(
          store,
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 420,
                child: ProductCard(product: piece, onQuickView: onQuickView),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await withSemantics(tester, () async {
      var longPresses = 0;
      await mount(product, () => longPresses++);

      expect(find.byKey(quickAddKey(product.id)), findsNothing);
      expect(find.byTooltip('Vista rápida'), findsNothing);
      final heart = find.byTooltip('Guardar en favoritos');
      expect(tester.getSize(heart).width, greaterThanOrEqualTo(48 - 0.01));
      expect(tester.getSize(heart).height, greaterThanOrEqualTo(48 - 0.01));
      final tile = find.byType(MonettaProductTile);
      final node = tester.getSemantics(tile).getSemanticsData();
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.hint, 'Abre la vista previa');
      expect(node.label, contains(cardTitle(store, product)));

      await tester.longPress(tile);
      await tester.pump();
      expect(longPresses, 1);

      await tester.tap(find.byType(AspectRatio).first);
      await tester.pumpAndSettle();
      expect(quickViewSheet(), findsOneWidget);
      expect(store.bagQuantity, 0, reason: 'opening the sheet adds nothing');

      // A sold-out piece opens the same sheet from its card.
      await tester.tapAt(const Offset(8, 40));
      await tester.pumpAndSettle();
      await mount(soldOut, () => longPresses++);
      expect(find.byKey(quickAddKey(soldOut.id)), findsNothing);
      await tester.tap(find.byType(AspectRatio).first);
      await tester.pumpAndSettle();
      expect(quickViewSheet(), findsOneWidget);
    });
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
