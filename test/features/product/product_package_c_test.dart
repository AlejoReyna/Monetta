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

  testWidgets('ficha Fig.07: galería contenida, precio y confianza',
      (tester) async {
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
    expect(find.byTooltip('Guardar'), findsWidgets);
    expect(find.byTooltip('Compartir'), findsOneWidget);

    // Trust row from the reference strip.
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Importado de EE. UU.'), findsOneWidget);
    expect(find.text('Pago seguro'), findsOneWidget);

    // Shipping facts, never lamina copy.
    expect(find.textContaining('Envío gratis desde'), findsWidgets);
    expect(find.textContaining('Entrega estimada'), findsWidgets);

    // Purchase bar: same labels the catalog flow already honours.
    expect(find.text('AGREGAR A LA BOLSA'), findsOneWidget);
    expect(find.text('COMPRAR AHORA'), findsOneWidget);
    expect(find.text('APARTAR'), findsOneWidget);
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

  testWidgets('swatches con mapeo fiable, chips en caso contrario',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final reliable = store.products.firstWhere(
      hasReliableColorOptions,
    );
    await _pumpFicha(tester, store, reliable.id);
    expect(find.text('COLOR'), findsOneWidget);
    expect(find.text('OPCIÓN'), findsNothing);

    final composed = store.products.firstWhere(
      (item) =>
          selectableVariants(item).isNotEmpty && !hasReliableColorOptions(item),
    );
    await _pumpFicha(tester, store, composed.id);
    expect(find.text('OPCIÓN'), findsOneWidget);
    expect(find.text('COLOR'), findsNothing);
  });

  testWidgets('acordeones Descripción, Detalles y Envíos', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final product = store.products.firstWhere((item) => item.isInStock);
    await _pumpFicha(tester, store, product.id);

    for (final label in ['Descripción', 'Detalles', 'Envíos y cambios']) {
      expect(find.text(label), findsOneWidget);
      await tester.ensureVisible(find.text(label));
      await tester.pump();
      await tester.tap(find.text(label));
      await tester.pump();
    }
    // Shipping terms open; internal slugs never leak.
    expect(find.textContaining('DHL'), findsOneWidget);
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

    await tester.tap(find.byTooltip('Guardar').first);
    await tester.pump();
    expect(store.wishlist.contains(product.id), isTrue);

    // Reopening the ficha keeps the state — no navigation happened.
    await _pumpFicha(tester, store, product.id);
    expect(store.wishlist.contains(product.id), isTrue);
    expect(find.byType(ProductScreen), findsOneWidget);
  });

  testWidgets('variante no disponible se distingue y avisa', (tester) async {
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
    expect(find.text('AVÍSAME CUANDO VUELVA'), findsOneWidget);
    expect(find.text('AGREGAR A LA BOLSA'), findsNothing);
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
    expect(find.text('AGREGAR A LA BOLSA'), findsOneWidget);
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

    // Sheet: drag handle, close X, brand–name–price, no fake urgency.
    expect(find.byTooltip('Cerrar vista rápida'), findsOneWidget);
    expect(find.text('AGREGAR A LA BOLSA'), findsOneWidget);
    expect(find.text('VER PRODUCTO'), findsOneWidget);
    expect(find.textContaining('Últimas'), findsNothing);

    // Same add-to-bag as the ficha: closes, then confirms with mini-cart.
    await tester.tap(find.text('AGREGAR A LA BOLSA'));
    await tester.pumpAndSettle();
    expect(store.bagQuantity, 1);
    expect(find.text('En tu bolsa'), findsOneWidget);
    expect(find.text('VER BOLSA'), findsOneWidget);
  });

  testWidgets('quick-view Ver producto abre la ficha', (tester) async {
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

    await tester.tap(find.text('VER PRODUCTO'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductScreen), findsOneWidget);
    expect(find.text('COMPRAR AHORA'), findsOneWidget);
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
    expect(find.text('AGREGAR A LA BOLSA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
