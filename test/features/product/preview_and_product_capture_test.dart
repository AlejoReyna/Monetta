/// 390×844 captures of the redesigned preview card and product page, with the
/// real bundled fonts and the fixture photograph.
///
/// Writes PNGs only when `MONETTA_1TO1_CAPTURE_DIR` is set. The assertions
/// (the card exists, no layout exception) run either way.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/features/product/quick_view.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/reco/events.dart';

import '../../support/client_guide_capture.dart';

const _phone = Size(390, 844);

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

/// A piece with several photographs, colour swatches and a real compare-at
/// price, so the card shows every element of the design.
Product _showcase(CatalogStore store) {
  bool fits(Product p, {required bool sale}) =>
      p.isInStock &&
      p.images.length > 1 &&
      hasReliableColorOptions(p) &&
      selectableVariants(p).length > 1 &&
      store.facetsFor(p.id)?.brand != null &&
      (!sale || p.isOnSale);
  return store.products.firstWhere(
    (p) => fits(p, sale: true),
    orElse: () => store.products.firstWhere((p) => fits(p, sale: false)),
  );
}

/// Writes the current frame, exactly as laid out (no page expansion).
Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['MONETTA_1TO1_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      try {
        await precacheImage(image.image, element, onError: (_, __) {}).timeout(
          const Duration(seconds: 2),
        );
      } on Object {
        // A missing still is not a reason to hang the harness.
      }
    }
  });
  await tester.pump();
  final renderView = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = renderView.debugLayer! as OffsetLayer;
    final ratio = 1 / renderView.flutterView.devicePixelRatio;
    final image = await layer.toImage(
      renderView.paintBounds,
      pixelRatio: ratio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp',
    );
    final fixture = File('test/support/fixture_product.jpg');
    if (fixture.existsSync()) {
      debugMonettaFixtureImage = MemoryImage(fixture.readAsBytesSync());
    }
  });

  tearDown(() {
    debugMonettaFixtureImage = null;
  });

  Future<void> openPreview(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
      ),
      size: _phone,
      brightness: brightness,
    );
    final context = tester.element(find.byType(CollectionScreen));
    final showcase = _showcase(catalog);
    unawaited(showProductQuickView(context, showcase));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-view-card')), findsOneWidget);
  }

  testWidgets('b-01 vista previa sobre la coleccion (claro)', (tester) async {
    await openPreview(tester);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'b-01-vista-previa');
  });

  testWidgets('b-02 vista previa (oscuro)', (tester) async {
    await openPreview(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'b-02-vista-previa-oscuro');
  });

  Future<void> openProductPage(WidgetTester tester) async {
    final catalog = await _catalog();
    final showcase = _showcase(catalog);
    // A viewed piece fills "Vistas hace un momento" as well.
    catalog.record(
      EventType.productView,
      productId: catalog.products.firstWhere((p) => p.id != showcase.id).id,
    );
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: ProductScreen(productId: showcase.id),
      ),
      size: _phone,
    );
    expect(find.byType(ProductScreen), findsOneWidget);
  }

  testWidgets('b-03 ficha arriba (claro)', (tester) async {
    await openProductPage(tester);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'b-03-ficha-arriba');
  });

  testWidgets('b-04 ficha desplazada hasta relacionados (claro)',
      (tester) async {
    await openProductPage(tester);
    final related = find.text('Productos relacionados');
    final scroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(related, 300, scrollable: scroll);
    await tester.pumpAndSettle();
    // Put the heading near the top of the screen.
    await tester.drag(scroll, const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(related, findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'b-04-ficha-relacionados');
  });
}
