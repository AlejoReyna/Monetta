import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/motion.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/product/product_screen.dart';

import '../../support/product_screen_harness.dart';

void main() {
  for (final action in ['swipe', 'button', 'system']) {
    testWidgets('product $action back records one view after leaving',
        (tester) async {
      setPhoneView(tester);
      final database = openTestDatabase();
      final store = CatalogStore(database: database);
      addTearDown(() async {
        store.dispose();
        await database.close();
      });
      await store.loadFromAsset();
      final product = syntheticProduct();
      addProducts(store, [product]);
      await tester.pumpWidget(
        fichaApp(store, const Scaffold(body: Text('Previous page'))),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push<void>(
          monettaPageRoute<void>(ProductScreen(productId: product.id)),
        ),
      );
      await tester.pumpAndSettle();
      final eventsBefore = store.eventCount;

      if (action == 'swipe') {
        // A short drag must cancel without recording a completed product view.
        final cancelled = await tester.startGesture(const Offset(5, 300));
        await cancelled.moveBy(const Offset(30, 0));
        await tester.pump();
        await cancelled.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 500));
        await cancelled.up();
        await tester.pumpAndSettle();
        expect(find.byType(ProductScreen), findsOneWidget);
        expect(store.eventCount, eventsBefore);

        final swipe = await tester.startGesture(const Offset(5, 300));
        await swipe.moveBy(const Offset(30, 0));
        await tester.pump();
        await swipe.moveBy(const Offset(250, 0));
        await tester.pump();
        expect(navigator.userGestureInProgress, isTrue);
        expect(store.eventCount, eventsBefore);
        await swipe.up();
      } else if (action == 'button') {
        await tester.tap(find.byKey(kHeaderBackKey));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsNothing);
      expect(find.text('Previous page'), findsOneWidget);
      expect(store.eventCount, eventsBefore + 1);
      expect(store.recentlyViewed().single.id, product.id);
    });
  }
}
