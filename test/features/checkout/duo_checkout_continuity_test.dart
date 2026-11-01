import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/cart/checkout_launcher.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets(
      'cart reflows progress, heading, full name and quantity at largest text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final store = CatalogStore(database: openTestDatabase());
    await store.loadFromAsset();
    addTearDown(store.dispose);
    final product = store.products.firstWhere((p) => p.isInStock);
    await store.addToBag(product);
    final scale = ValueNotifier(1.0);
    addTearDown(scale.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => ValueListenableBuilder(
          valueListenable: scale,
          child: child,
          builder: (context, value, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(value)),
            child: child!,
          ),
        ),
        home: StoreScope(notifier: store, child: const BagScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final original = tester.state(find.byType(BagScreen));
    scale.value = 3.2;
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(BagScreen)), same(original));
    final progress = find.text('Paso 1 de 4 · Bolsa');
    expect(progress, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(progress).textScaler.scale(12),
      12 * 3.2,
    );
    expect(find.byKey(const ValueKey('bag-heading-stacked')), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Agregar uno'));
    await tester.pumpAndSettle();
    final name =
        tester.renderObject<RenderParagraph>(find.text(product.title).first);
    expect(name.didExceedMaxLines, isFalse);
    expect(name.maxLines, isNull);
    final add = tester.getRect(find.byTooltip('Agregar uno'));
    expect(add.height, greaterThanOrEqualTo(48));
    expect(add.top, greaterThanOrEqualTo(0));
    expect(add.bottom, lessThanOrEqualTo(844));
    final quantity = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Cantidad 1',
      ),
      matching: find.text('1'),
    );
    final glyph = tester.getRect(quantity);
    expect(glyph.top, greaterThanOrEqualTo(add.top));
    expect(glyph.bottom, lessThanOrEqualTo(add.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'contact draft and one fake checkout launch survive resizing and cancellation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final store = CatalogStore(database: openTestDatabase());
    await store.loadFromAsset();
    addTearDown(store.dispose);
    await store.addToBag(store.products.firstWhere((p) => p.isInStock));
    final pending = Completer<CheckoutResult>();
    final drafts = <CheckoutDraft>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: StoreScope(
          notifier: store,
          child: CheckoutFlowScreen(
            launchSecureCheckout: (draft) {
              drafts.add(draft);
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final state = tester.state(find.byType(CheckoutFlowScreen));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'buyer@example.invalid');
    await tester.enterText(fields.at(1), '8112345678');
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    final edits = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((field) => field.controller.text)
        .toList();
    expect(edits, containsAll(['buyer@example.invalid', '8112345678']));
    expect(tester.state(find.byType(CheckoutFlowScreen)), same(state));
    await tester.ensureVisible(find.text('REVISAR PEDIDO'));
    await tester.tap(find.text('REVISAR PEDIDO'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.tap(find.text('CONTINUAR AL PAGO SEGURO'));
    await tester.pump();
    expect(drafts, hasLength(1));
    for (final size in [
      const Size(390, 844),
      const Size(1024, 768),
      const Size(768, 1024),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.state(find.byType(CheckoutFlowScreen)), same(state));
      expect(drafts, hasLength(1));
    }
    expect(drafts.single.email, 'buyer@example.invalid');
    expect(
      drafts.single.lines.single.variant.id,
      store.bagLines.single.variant.id,
    );
    pending.complete(const CheckoutCancelled());
    await tester.pumpAndSettle();
    expect(drafts, hasLength(1));
    expect(store.bagQuantity, 1);
    expect(find.text('Estamos revisando tu pago'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
