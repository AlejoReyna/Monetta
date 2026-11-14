// REVIEW FIXTURES ONLY: owner-provided photographs, illustrative stock/prices.
// No network, provider response, golden approval or production catalog mutation.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/normalize/normalizer.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_zoom.dart';
import 'package:monetta_app/features/product/quick_view.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/reco/events.dart';
import '../../support/client_guide_capture.dart';
import '../../support/product_screen_harness.dart';

const _source = 'test/support/v41';
Product _product() => Product(
      id: 'gid://shopify/Product/9901',
      handle: 'visual-fixture',
      title: 'Reloj Coach Iris Charms',
      vendor: 'Coach',
      productType: 'Reloj',
      tags: const ['Coach', 'Reloj'],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      descriptionHtml:
          '<p>Descripción de prueba del producto; contenido ilustrativo para revisión local.</p>',
      variants: const [
        ProductVariant(
          id: 'gid://shopify/ProductVariant/99011',
          title: 'Plateado/Dorado',
          price: 7219,
          available: true,
          selectedOptions: {'Color': 'Plateado/Dorado'},
          imageUrls: ['https://cdn.shopify.com/fixture/iris-plateado.png'],
        ),
        ProductVariant(
          id: 'gid://shopify/ProductVariant/99012',
          title: 'Dorado',
          price: 7219,
          available: false,
          selectedOptions: {'Color': 'Dorado'},
          imageUrls: ['https://cdn.shopify.com/fixture/iris-dorado.png'],
        ),
      ],
      images: const [],
    );
Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['MONETTA_A02_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage(
        (element.widget as Image).image,
        element,
        onError: (_, __) {},
      );
    }
  });
  await tester.pump();
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final image = await (view.debugLayer! as OffsetLayer)
        .toImage(view.paintBounds, pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(mockPathProvider);
  tearDown(() => debugMonettaFixtureImage = null);
  for (final mode in [
    (390.0, 1.0, Brightness.light),
    (390.0, 1.0, Brightness.dark),
    (320.0, 2.0, Brightness.light),
  ]) {
    final suffix = '${mode.$1.toInt()}-${mode.$2.toInt()}x-${mode.$3.name}';
    Future<CatalogStore> mount(
      WidgetTester tester,
      Widget Function(Product) child, {
      bool gold = false,
    }) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.loadFromAsset();
      final p = _product();
      store.products = [...store.products, p];
      store.facetsById = {
        ...store.facetsById,
        p.id: Normalizer(store.rules)
            .normalize(p, now: DateTime.utc(2026, 11, 11)),
      };
      debugMonettaFixtureImage = MemoryImage(
        File(
          '$_source/${gold ? 'iris-dorado.png' : 'iris-plateado-dorado.png'}',
        ).readAsBytesSync(),
      );
      await pumpClientGuide(
        tester,
        StoreScope(notifier: store, child: child(p)),
        size: Size(mode.$1, 844),
        textScale: mode.$2,
        brightness: mode.$3,
      );
      return store;
    }

    testWidgets('common card $suffix', (tester) async {
      await mount(
        tester,
        (p) => Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProductCard(product: p, initialVariantId: p.variants[1].id),
            ],
          ),
        ),
        gold: true,
      );
      if (mode.$2 == 2) {
        final caption = find.descendant(
          of: find.byType(MonettaProductTile),
          matching: find.text(_product().title),
        );
        expect(paragraphOf(tester, caption).didExceedMaxLines, false);
      }
      await capture(tester, 'card-$suffix');
      expect(tester.takeException(), isNull);
    });
    testWidgets('quick view $suffix', (tester) async {
      final store =
          await mount(tester, (_) => const Scaffold(body: SizedBox()));
      final context = tester.element(find.byType(Scaffold));
      unawaited(showProductQuickView(context, store.products.last));
      await tester.pumpAndSettle();
      await capture(tester, 'quick-$suffix');
      expect(tester.takeException(), isNull);
      await tester
          .ensureVisible(find.byKey(const Key('quick-view-view-product')));
      await tester.pumpAndSettle();
      await capture(tester, 'quick-actions-$suffix');
      expect(tester.takeException(), isNull);
    });
    testWidgets('PDP details $suffix', (tester) async {
      await mount(
        tester,
        (p) => ProductScreen(
          productId: p.id,
          shippingPolicy: 'Política de envíos de prueba. No publicada.',
          returnsPolicy: 'Política de cambios de prueba. No publicada.',
          endSectionsBuilder: (_) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Conexión editorial de prueba A06'),
          ),
        ),
      );
      await capture(tester, 'pdp-$suffix');
      expect(tester.takeException(), isNull);
      for (var step = 0;
          step < 15 &&
              find
                  .text('Otras formas de comprar')
                  .hitTestable()
                  .evaluate()
                  .isEmpty;
          step++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(
        find.text('Otras formas de comprar').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Otras formas de comprar').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Solicitar apartado por WhatsApp'), findsOneWidget);
      await capture(tester, 'details-$suffix');
      expect(tester.takeException(), isNull);
      final position = tester.state<ScrollableState>(mainScrollable()).position;
      final apartado = find.byKey(const Key('purchase-apartar'));
      position.jumpTo(
        (position.pixels + tester.getTopLeft(apartado).dy - 200)
            .clamp(0.0, position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
      expect(apartado.hitTestable(), findsOneWidget);
      await capture(tester, 'details-actions-$suffix');
      expect(tester.takeException(), isNull);
    });
    testWidgets('recommendation rail and same-set continuation $suffix',
        (tester) async {
      final store = await mount(tester, (p) => ProductScreen(productId: p.id));
      store.record(EventType.productView, productId: store.products.first.id);
      await tester.pumpAndSettle();
      final heading = find.text('Más de la marca');
      expect(heading, findsOneWidget);
      final position = tester.state<ScrollableState>(mainScrollable()).position;
      position.jumpTo(
        (position.pixels + tester.getTopLeft(heading).dy - 120)
            .clamp(0.0, position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'recommendations-$suffix');
      expect(tester.takeException(), isNull);
      final link = find.byKey(const ValueKey('product-set-Más de la marca'));
      position.jumpTo(
        (position.pixels + tester.getTopLeft(link).dy - 400)
            .clamp(0.0, position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
      await tester.tap(link.hitTestable());
      await tester.pumpAndSettle();
      final grid =
          find.byKey(const ValueKey('product-set-grid-Más de la marca'));
      expect(grid, findsOneWidget);
      final expected = store
          .moreFromBrand('coach', excluding: store.products.last.id, limit: 40)
          .map((p) => p.id)
          .toSet();
      expect(
        tester.widget<GridView>(grid).childrenDelegate.estimatedChildCount,
        expected.length,
      );
      final visible = tester
          .widgetList<ProductCard>(
            find.descendant(of: grid, matching: find.byType(ProductCard)),
          )
          .map((card) => card.product.id)
          .toList();
      expect(visible.toSet().length, visible.length);
      expect(expected.containsAll(visible), true);
      await capture(tester, 'recommendation-set-$suffix');
      expect(tester.takeException(), isNull);
    });
    testWidgets('zoom $suffix', (tester) async {
      final store =
          await mount(tester, (_) => const Scaffold(body: SizedBox()));
      final context = tester.element(find.byType(Scaffold));
      unawaited(
        showProductZoom(
          context,
          images: store.products.last.variants.first.imageUrls,
          initialPage: 0,
          title: 'Plateado/Dorado',
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'zoom-$suffix');
      expect(tester.takeException(), isNull);
    });
  }
}
