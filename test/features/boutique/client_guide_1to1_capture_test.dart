/// 390×844 light captures for the 19 client-guide pages.
///
/// Writes PNGs only when `MONETTA_1TO1_CAPTURE_DIR` is set. The assertions
/// still run without that directory.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/categories_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/checkout/order_confirmation_screen.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/navigation/monetta_side_menu.dart';
import 'package:monetta_app/features/orders/orders_screen.dart';
import 'package:monetta_app/features/personalization/personalization_screen.dart';
import 'package:monetta_app/features/personalization/shopper_preferences.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/quick_view.dart';
import 'package:monetta_app/features/rewards/rewards_guide_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import 'package:monetta_app/features/rewards/rewards_share_screen.dart';
import 'package:monetta_app/features/welcome/welcome_screen.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';
import 'package:monetta_app/main.dart';

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

AccountController _account() {
  final db = openTestDatabase();
  addTearDown(db.close);
  final controller = AccountController(
    accountStore: AccountStore(db),
    deviceStore: DeviceStore(db),
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    deviceId: 'guide-1to1',
  )
    ..account = Account(
      localAccountId: 'guide-account',
      authProvider: 'shopify',
      displayName: 'Ana',
      email: 'ana@email.com',
      createdAt: DateTime.utc(2026),
      lastSeenAt: DateTime.utc(2026),
    )
    ..orders = [
      OrderSummary(
        id: 'fixture-1',
        accountId: 'guide-account',
        displayNumber: '#MNT2345',
        source: 'shopify_checkout',
        status: 'paid',
        fulfillmentStatus: 'in_transit',
        totalAmount: 11480,
        currencyCode: 'MXN',
        placedAt: DateTime.utc(2025, 5, 11),
      ),
    ]
    ..ordersStatus = OrderHistoryStatus.populated;
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp',
    );
  });

  testWidgets('01 bienvenida', (tester) async {
    await pumpClientGuide(tester, WelcomeScreen(onStart: () {}), size: _phone);
    expect(find.text('COMENZAR'), findsOneWidget);
    await captureClientGuide(tester, 'p-01-bienvenida');
  });

  testWidgets('02 personalizacion', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: PersonalizationScreen(
          store: MemoryShopperPreferenceStore(),
          scopeKey: 'guide',
        ),
      ),
      size: _phone,
    );
    expect(find.text('Personalización'), findsOneWidget);
    await captureClientGuide(tester, 'p-02-personalizacion');
  });

  testWidgets('03 pagina principal', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(notifier: catalog, child: const HomeScreen()),
      size: _phone,
    );
    expect(find.text('COLECCIÓN'), findsOneWidget);
    await captureClientGuide(tester, 'p-03-inicio');
  });

  testWidgets('04 seguimiento', (tester) async {
    final catalog = await _catalog();
    // Product tiles use CachedNetworkImage. Scrolling them in leaves
    // CacheStore's cleanup timer pending after the test. The hero itself
    // is an asset, so the capture does not need the CDN photos.
    catalog.products = [
      for (final product in catalog.products)
        Product(
          id: product.id,
          handle: product.handle,
          title: product.title,
          vendor: product.vendor,
          productType: product.productType,
          tags: product.tags,
          variants: product.variants,
          images: const [],
          createdAt: product.createdAt,
          updatedAt: product.updatedAt,
          descriptionHtml: product.descriptionHtml,
          collectionHandles: product.collectionHandles,
          brandOverride: product.brandOverride,
          categoryOverride: product.categoryOverride,
        ),
    ];
    await pumpClientGuide(
      tester,
      StoreScope(notifier: catalog, child: const HomeScreen()),
      size: _phone,
    );
    final scroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-followup-hero')),
      400,
      scrollable: scroll,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('TUS MODELOS'), findsOneWidget);
    await captureClientGuide(tester, 'p-04-seguimiento');
  });

  testWidgets('05 busqueda', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: SearchScreen(initialQuery: 'Bolso', history: SearchHistory()),
      ),
      size: _phone,
    );
    expect(find.text('Inicio'), findsWidgets);
    await captureClientGuide(tester, 'p-05-busqueda');
  });

  testWidgets('06 coleccion', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: const CollectionScreen(
          title: 'Coach',
          filter: CollectionFilter(brand: 'coach'),
        ),
      ),
      size: _phone,
    );
    expect(find.text('Coach'), findsWidgets);
    await captureClientGuide(tester, 'p-06-coleccion');
  });

  testWidgets('07 preview', (tester) async {
    final catalog = await _catalog();
    final product = catalog.products.firstWhere((item) => item.isInStock);
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showProductQuickView(context, product),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
      size: _phone,
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar a bolsa'), findsOneWidget);
    await captureClientGuide(tester, 'p-07-preview');
  });

  testWidgets('08 ficha', (tester) async {
    final catalog = await _catalog();
    final product = catalog.products.firstWhere((item) => item.isInStock);
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: ProductScreen(productId: product.id),
      ),
      size: _phone,
    );
    expect(find.text('Agregar a bolsa'), findsOneWidget);
    await captureClientGuide(tester, 'p-08-producto');
  });

  testWidgets('09 coleccion sin marca fija', (tester) async {
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
    );
    expect(find.text('Bolsas'), findsWidgets);
    await captureClientGuide(tester, 'p-09-coleccion');
  });

  testWidgets('10 mayoreo', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(notifier: catalog, child: const WholesaleScreen()),
      size: _phone,
    );
    expect(find.text('MAYOREO'), findsOneWidget);
    await captureClientGuide(tester, 'p-10-mayoreo');
  });

  testWidgets('11 mayoreo continuidad', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(notifier: catalog, child: const WholesaleScreen()),
      size: _phone,
    );
    final scroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('¿Tienes dudas?'),
      400,
      scrollable: scroll,
    );
    await tester.pumpAndSettle();
    await captureClientGuide(tester, 'p-11-mayoreo-continuidad');
  });

  testWidgets('12 pedidos', (tester) async {
    final catalog = await _catalog();
    final account = _account();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: OrdersScreen(
          controller: account,
          rewardsReader: FakeRewardsReader(),
        ),
      ),
      size: _phone,
    );
    expect(find.text('Mis pedidos'), findsWidgets);
    await captureClientGuide(tester, 'p-12-pedidos');
  });

  testWidgets('13 cuenta', (tester) async {
    final account = _account();
    await pumpClientGuide(
      tester,
      AccountScreen(controller: account, rewardsReader: FakeRewardsReader()),
      size: _phone,
    );
    expect(find.text('Ana'), findsOneWidget);
    await captureClientGuide(tester, 'p-13-cuenta');
  });

  testWidgets('14 rewards', (tester) async {
    await pumpClientGuide(
      tester,
      RewardsGuideScreen(reader: _Reader(_summary())),
      size: _phone,
    );
    expect(find.textContaining('Pendiente de contrato'), findsWidgets);
    await captureClientGuide(tester, 'p-14-rewards');
  });

  testWidgets('15 rewards compartir', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(notifier: catalog, child: const RewardsShareScreen()),
      size: _phone,
    );
    expect(find.text('Comparte y gana'), findsOneWidget);
    await captureClientGuide(tester, 'p-15-rewards-share');
  });

  testWidgets('16 contacto', (tester) async {
    await pumpClientGuide(tester, const ContactScreen(), size: _phone);
    expect(find.text('Contáctanos'), findsOneWidget);
    await captureClientGuide(tester, 'p-16-contacto');
  });

  testWidgets('17 compra', (tester) async {
    await pumpClientGuide(
      tester,
      const OrderConfirmationScreen(orderLabel: '#MNT2345'),
      size: _phone,
    );
    expect(find.text('¡Gracias por tu compra!'), findsOneWidget);
    await captureClientGuide(tester, 'p-17-compra');
  });

  testWidgets('18 categorias', (tester) async {
    final catalog = await _catalog();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: catalog,
        child: CategoriesScreen(content: HomeContent.fallback),
      ),
      size: _phone,
    );
    expect(find.text('Categorías'), findsWidgets);
    await captureClientGuide(tester, 'p-18-categorias');
  });

  testWidgets('19 menu', (tester) async {
    await pumpClientGuide(
      tester,
      MonettaSideMenu(
        onSearch: () {},
        onCatalog: () {},
        onCategories: () {},
        onBags: () {},
        onWallets: () {},
        onWatches: () {},
        onPerfumes: () {},
        onBeauty: () {},
        onToggleTheme: () {},
        onAbout: () {},
        onPartner: () {},
        onSupport: () {},
        identityName: 'mapachesdev98',
        identityDetail: 'mapachesdev98@gmail.com',
      ),
      size: _phone,
    );
    expect(find.text('Bolsas'), findsOneWidget);
    await captureClientGuide(tester, 'p-19-menu');
  });
}

RewardsSummary _summary() => RewardsSummary(
      redemptionEnabled: false,
      availableCents: 18400,
      pendingCents: 0,
      reservedCents: 0,
      nextExpiry: null,
      asOf: DateTime.utc(2026, 9, 14),
      firstPurchaseEnabled: false,
      reviewEnabled: false,
      referralEnabled: false,
    );

class _Reader implements RewardsReader {
  _Reader(this.value);
  final RewardsSummary value;

  @override
  Future<({List<RewardsMovement> movements, String? nextCursor})>
      activity() async =>
          (movements: const <RewardsMovement>[], nextCursor: null);

  @override
  Future<OrderRewardsState> orderRewards(String shopifyOrderId) {
    throw UnimplementedError();
  }

  @override
  Future<RewardsSummary> summary() async => value;
}
