// Read-only audit fixtures. Run from the repository root; no live services.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/favorites/favorites_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/orders/order_detail_screen.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';
import 'package:monetta_app/main.dart';

import '../../../test/support/client_guide_capture.dart';

const _out = 'docs/audits/2026-11-11-v41/evidence';

Future<CatalogStore> _catalog() async {
  final db = openTestDatabase();
  final store = CatalogStore(database: db);
  addTearDown(() async {
    store.dispose();
    await db.close();
  });
  await store.loadFromAsset();
  return store;
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump();
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds, pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => '/tmp',
    );
    debugMonettaFixtureImage =
        MemoryImage(File('test/support/fixture_product.jpg').readAsBytesSync());
  });
  tearDown(() {
    debugMonettaFixtureImage = null;
    debugDefaultTargetPlatformOverride = null;
  });

  for (final (width, height, scale) in [
    (320.0, 640.0, 2.0),
    (390.0, 844.0, 1.0),
    (768.0, 1024.0, 1.0),
    (1440.0, 1000.0, 1.0),
  ]) {
    testWidgets('Home viewport $width at text scale $scale', (tester) async {
      final store = await _catalog();
      await pumpClientGuide(
        tester,
        StoreScope(notifier: store, child: const HomeScreen()),
        size: Size(width, height),
        textScale: scale,
      );
      await _capture(
          tester, 'viewport-home-${width.toInt()}-${scale.toInt()}x');
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, screen) in <(String, Widget)>[
    ('contact', const ContactScreen()),
    ('wholesale', const WholesaleScreen()),
  ]) {
    testWidgets('$name viewport 320 at text scale 2', (tester) async {
      final store = await _catalog();
      await pumpClientGuide(
        tester,
        StoreScope(notifier: store, child: screen),
        size: const Size(320, 640),
        textScale: 2,
      );
      await _capture(tester, 'viewport-$name-320-2x');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Favorites with saved products', (tester) async {
    final store = await _catalog();
    await store.toggleWishlist(store.products.first.id);
    await pumpClientGuide(
      tester,
      StoreScope(notifier: store, child: const FavoritesScreen()),
    );
    await _capture(tester, 'viewport-favorites-390');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Order detail with confirmed shipment', (tester) async {
    await pumpClientGuide(
      tester,
      OrderDetailScreen(
        order: OrderSummary(
          id: 'audit-order',
          accountId: 'audit-account',
          displayNumber: '#AUDIT',
          source: 'shopify_checkout',
          status: 'paid',
          fulfillmentStatus: 'in_transit',
          totalAmount: 1200,
          currencyCode: 'MXN',
          placedAt: DateTime.utc(2026, 11, 1),
        ),
      ),
    );
    await _capture(tester, 'viewport-order-390');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sold out product card', (tester) async {
    final store = await _catalog();
    final source = store.products.first;
    final sold = Product(
      id: source.id,
      handle: source.handle,
      title: source.title,
      vendor: source.vendor,
      productType: source.productType,
      tags: source.tags,
      variants: [
        for (final variant in source.variants)
          ProductVariant(
            id: variant.id,
            title: variant.title,
            price: variant.price,
            compareAtPrice: variant.compareAtPrice,
            available: false,
          ),
      ],
      images: source.images,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
    );
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: Scaffold(
          body: Center(
              child: SizedBox(width: 220, child: ProductCard(product: sold))),
        ),
      ),
    );
    await _capture(tester, 'viewport-sold-out-390');
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS Home viewport', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final store = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(notifier: store, child: const HomeScreen()),
    );
    await _capture(tester, 'viewport-home-ios-390');
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });
}
