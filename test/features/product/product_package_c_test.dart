import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/features/product/quick_view.dart';
import 'package:monetta_app/main.dart';

import '../../support/product_screen_harness.dart';
import '../../support/quick_add_harness.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Future<void> _pumpFicha(
  WidgetTester tester,
  CatalogStore store,
  String productId,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: ProductScreen(productId: productId),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // Ver nota en product_package_c_captures_test.dart: mock de path_provider
  // para que el caché de imágenes no falle de forma intermitente en tests.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp',
    );
  });

  testWidgets('ficha Fig.07: galería contenida, precio y confianza', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere(
      (item) => item.isInStock && item.images.length > 1,
    );
    await _pumpFicha(tester, store, product.id);

    // Gallery never crops the handles.
    final heroImage = find.descendant(
      of: find.byType(InteractiveViewer),
      matching: find.byType(MonettaImage),
    );
    expect(heroImage, findsWidgets);
    expect(tester.widget<MonettaImage>(heroImage.first).fit, BoxFit.contain);

    // Thumbnails + wishlist + share live on the gallery.
    expect(find.byKey(const ValueKey('thumb-0')), findsOneWidget);
    expect(find.byTooltip('Guardar en favoritos'), findsWidgets);
    expect(find.byTooltip('Compartir'), findsOneWidget);

    // UI v4.1 services under the purchase buttons, with the delivered copy.
    final services = find.byKey(const Key('product-trust-row'));
    await scrollTo(tester, services);
    for (final text in [
      'ENVÍO GRATIS',
      '5 - 7 días hábiles',
      'Producto Original',
      'Importado desde E.U.A',
      'Paga a Meses',
      'Sin Intereses',
    ]) {
      expect(
        find.descendant(of: services, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }

    expect(find.text('Agregar al carrito'), findsOneWidget);
    await scrollTo(tester, find.text('Comprar ahora'));
    expect(find.text('Comprar ahora'), findsOneWidget);
  });

  testWidgets('descuento solo con compare_at real', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final onSale = store.products.firstWhere(
      (item) => item.isOnSale && item.images.isNotEmpty,
    );
    await _pumpFicha(tester, store, onSale.id);
    // The badge carries a key so related cards cannot fake the assertion.
    expect(find.byKey(const ValueKey('discount-badge')), findsWidgets);

    final plain = store.products.firstWhere(
      (item) =>
          item.isInStock &&
          !item.isOnSale &&
          item.images.isNotEmpty &&
          item.id != onSale.id,
    );
    await _pumpFicha(tester, store, plain.id);
    // Price block, purchase bar and sheet share the key — none may render.
    expect(find.byKey(const ValueKey('discount-badge')), findsNothing);
  });

  testWidgets('swatches con mapeo fiable, chips en caso contrario', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    // The bundled catalog names no colour option; a synthetic piece does.
    final reliable = swatchProduct();
    addProducts(store, [reliable]);
    await _pumpFicha(tester, store, reliable.id);
    // «Color: Negro»: the label carries the chosen colour.
    expect(find.textContaining('Color: '), findsOneWidget);
    expect(find.text('Opción'), findsNothing);

    final composed = store.products.firstWhere(
      (item) =>
          selectableVariants(item).isNotEmpty && !hasReliableColorOptions(item),
    );
    await _pumpFicha(tester, store, composed.id);
    // Without named options the variant titles are plain chips, no colour.
    expect(
      find.text(selectableVariants(composed).first.title.toUpperCase()),
      findsWidgets,
    );
    expect(find.textContaining('Color: '), findsNothing);
  });

  testWidgets(
      'acordeones Otras formas de comprar, Envíos y Cambios y devoluciones',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);
    await _pumpFicha(tester, store, product.id);

    // UI v4.1 order. Descripción, Envíos and Cambios y devoluciones appear
    // only with content (published policies); here none is published.
    expect(find.text('Envíos'), findsNothing);
    expect(find.text('Cambios y devoluciones'), findsNothing);
    for (final label in ['Otras formas de comprar']) {
      expect(find.text(label), findsOneWidget);
      await tester.ensureVisible(find.text(label));
      await tester.pump();
      await tester.tap(find.text(label));
      await tester.pump();
    }
    // The WhatsApp apartado appears only inside «Otras formas de comprar».
    expect(find.text('Solicitar apartado por WhatsApp'), findsOneWidget);
    expect(find.text('Gama'), findsNothing);
  });

  testWidgets('corazón guarda sin navegar y persiste', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere(
      (item) => item.isInStock && item.images.isNotEmpty,
    );
    expect(store.wishlist.contains(product.id), isFalse);
    await _pumpFicha(tester, store, product.id);

    await tester.tap(find.byTooltip('Guardar en favoritos').first);
    await tester.pump();
    expect(store.wishlist.contains(product.id), isTrue);

    // Reopening the ficha keeps the state — no navigation happened.
    await _pumpFicha(tester, store, product.id);
    expect(store.wishlist.contains(product.id), isTrue);
    expect(find.byType(ProductScreen), findsOneWidget);
  });

  testWidgets(
      'variante no disponible se distingue; sin servicio de reposición no '
      'ofrece aviso', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere(
      (item) =>
          item.variants.any((v) => !v.available) &&
          item.variants.any((v) => v.available),
    );
    final unavailable = product.variants.firstWhere((v) => !v.available);
    await _pumpFicha(tester, store, product.id);

    await tester.tap(find.text(unavailable.title.toUpperCase()));
    await tester.pump();
    expect(find.text('AGOTADO'), findsWidgets);
    // The restock alert waits for a real service (hidden, never inert).
    expect(find.text('Avísame cuando vuelva'), findsNothing);
    expect(find.text('Agregar al carrito'), findsNothing);
  });

  testWidgets('ficha sin foto no rompe y permite comprar', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    store.products = [
      ...store.products,
      Product(
        id: 'test-sin-foto',
        handle: 'test-sin-foto',
        title: 'Bolsa Test Sin Foto',
        vendor: '',
        productType: '',
        tags: const [],
        variants: const [
          ProductVariant(
            id: 'v-test',
            title: 'Default Title',
            price: 999,
            available: true,
          ),
        ],
        images: const [],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    ];
    await _pumpFicha(tester, store, 'test-sin-foto');
    expect(find.text('Bolsa Test Sin Foto'), findsWidgets);
    expect(find.text('Agregar al carrito'), findsOneWidget);
  });

  testWidgets('quick-view Fig.06: ver, agregar y volver', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere(
      (item) => item.isInStock && item.images.isNotEmpty,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showProductQuickView(context, product),
                  child: const Text('ABRIR'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('ABRIR'));
    await tester.pumpAndSettle();

    // Centred card: an accessible X and no back arrow (UI v4.1), brand–
    // name–price, no fake urgency.
    expect(find.byKey(const Key('quick-view-card')), findsOneWidget);
    expect(find.byTooltip('Cerrar vista previa'), findsOneWidget);
    expect(find.byTooltip('Regresar'), findsNothing);
    expect(find.text('Ver producto'), findsOneWidget);
    expect(find.textContaining('Últimas'), findsNothing);

    // Add confirms in place and leaves the cart shut.
    final primary = find.byKey(const Key('quick-view-primary'));
    if (selectableVariants(product).length > 1) {
      await pickVariant(tester, product, selectableVariants(product).first);
    }
    expect(find.text('Agregar al carrito'), findsOneWidget);
    await tester.tap(primary);
    await tester.pumpAndSettle();
    expect(store.bagQuantity, 1);
    expect(find.text('Agregado al carrito'), findsOneWidget);
    expect(find.text('En tu bolsa'), findsNothing);
  });

  testWidgets('quick-view «Ver producto» abre la ficha', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere(
      (item) => item.isInStock && item.images.isNotEmpty,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: StoreScope(
          notifier: store,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showProductQuickView(context, product),
                  child: const Text('ABRIR'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('ABRIR'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver producto'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsOneWidget);
    await scrollTo(tester, find.text('Comprar ahora'));
    expect(find.text('Comprar ahora'), findsOneWidget);
  });

  testWidgets('ficha aguanta texto ampliado y modo oscuro', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    });
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere(
      (item) => item.isInStock && item.images.length > 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.dark,
        home: StoreScope(
          notifier: store,
          child: ProductScreen(productId: product.id),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Agregar al carrito'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
