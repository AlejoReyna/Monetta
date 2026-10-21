/// UI-04 (reference goldens): the screens of the DEV-03 checklist at text scale
/// 1.0 with the real Inter, Playfair Display and MaterialIcons faces, at an
/// iPhone-small (375x812) and an iPhone Pro Max (440x956) viewport, at a device
/// pixel ratio of 3.0. The person approves the images; the test then pins them.
///
/// Screens: Inicio, Coleccion, Ficha, Bolsa (two lines, one with a long name)
/// and Cuenta. Each image is the first viewport, without scrolling.
///
/// Product images need the network and never load in tests, so cards stay in
/// their placeholder state, the same on every run. The tests carry the
/// `golden` tag: Linux skips them and local macOS runs them, with a pixel
/// tolerance of 0.5 % (see `tolerant_golden_comparator.dart`) because CoreText
/// can vary between macOS releases.
///
/// Regenerate only on purpose, and only into `test/goldens/ui04/`:
/// `flutter test --no-pub --update-goldens --tags golden test/goldens/`.
@Tags(<String>['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/notifications/notification_models.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/notifications/notification_inbox.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import 'package:monetta_app/main.dart';

import '../support/bundled_fonts.dart';
import '../support/product_screen_harness.dart' show mockPathProvider;
import '../support/tolerant_golden_comparator.dart';

/// Phones in logical pixels, at a device pixel ratio of 3.0.
const List<Size> _phones = <Size>[Size(375, 812), Size(440, 956)];

/// Largest accepted share of differing pixels (0.5 %).
const double _tolerance = 0.005;

/// A screen under test: its Spanish name, its file stem and its builder.
typedef _Build = Future<Widget> Function(CatalogStore store);

/// In-stock asset products, longest title first.
List<Product> _longestInStock(CatalogStore store) =>
    store.products.where((p) => p.isInStock).toList()
      ..sort((a, b) => b.title.length.compareTo(a.title.length));

AccountController _controller() {
  final db = openTestDatabase();
  addTearDown(db.close);
  return AccountController(
    accountStore: AccountStore(db),
    deviceStore: DeviceStore(db),
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    deviceId: 'dev-1',
  );
}

Account _account() => Account(
      localAccountId: 'acct-1',
      shopifyCustomerId: 'gid://shopify/Customer/1',
      email: 'ana.garcia@example.com',
      displayName: 'Ana García',
      authProvider: 'shopify',
      createdAt: DateTime.utc(2026, 1, 1),
      lastSeenAt: DateTime.utc(2026, 1, 1),
    );

OrderSummary _order() => OrderSummary(
      id: 'gid://shopify/Order/1',
      accountId: 'acct-1',
      displayNumber: '#1001',
      fulfillmentStatus: 'fulfilled',
      shopifyOrderId: 'gid://shopify/Order/1',
      source: 'shopify_checkout',
      status: 'paid',
      totalAmount: 11480,
      currencyCode: 'MXN',
      placedAt: DateTime.utc(2026, 5, 12),
    );

FakeRewardsReader _rewards() => FakeRewardsReader(
      summary: RewardsSummary(
        redemptionEnabled: true,
        availableCents: 18400,
        pendingCents: 5400,
        reservedCents: 0,
        nextExpiry: RewardsExpiry(cents: 2000, at: DateTime.utc(2027, 9, 10)),
        asOf: DateTime.utc(2026, 9, 14),
        firstPurchaseEnabled: false,
        reviewEnabled: false,
        referralEnabled: false,
      ),
      activity: [
        RewardsMovement(
          id: 1,
          type: 'earn_released',
          state: 'available',
          amountCents: 5400,
          orderShopifyId: 'gid://shopify/Order/1',
          reason: 'Se liberó al entregar tu pedido #1001.',
          createdAt: DateTime.utc(2026, 9, 10),
        ),
      ],
      perOrder: const {},
    );

NotificationInbox _inbox() => NotificationInbox()
  ..ingest(
    MonettaNotification(
      id: 'n1',
      title: 'Tu pedido va en camino',
      body: 'El pedido #1001 fue enviado.',
      route: const NotificationRouteData(type: 'home'),
      receivedAt: DateTime.utc(2026, 9, 10),
      ownerId: 'acct-1',
      kind: MonettaNotificationKind.order,
    ),
  );

/// The golden screens, keyed by the stem of the image file.
final Map<String, (String, _Build)> _screens = <String, (String, _Build)>{
  'inicio': (
    'Inicio',
    (store) async {
      _resetSearchPrompt();
      return const HomeScreen();
    },
  ),
  'coleccion': (
    'Coleccion',
    (store) async => const CollectionScreen(
          title: 'Bolsas',
          filter: CollectionFilter(category: 'bolsa'),
        ),
  ),
  'ficha': (
    'Ficha',
    (store) async => ProductScreen(productId: _longestInStock(store).first.id),
  ),
  'bolsa': (
    'Bolsa',
    (store) async {
      // Two lines: the longest title of the asset catalog and a shorter one.
      final products = _longestInStock(store);
      await store.addToBag(products.first);
      await store.addToBag(products.last);
      expect(store.bagLines.length, 2);
      return const BagScreen();
    },
  ),
  'cuenta': (
    'Cuenta',
    (store) async {
      final controller = _controller()
        ..account = _account()
        ..orders = [_order()]
        ..ordersStatus = OrderHistoryStatus.populated;
      return AccountScreen(
        controller: controller,
        rewardsReader: _rewards(),
        notificationInbox: _inbox(),
        canOpenAdmin: () => false,
        onOpenAdmin: () {},
        onOpenPartner: () {},
        onOpenInvite: () {},
      );
    },
  ),
};

/// Home keeps a process-wide counter that picks the search prompt of each new
/// Home. Advances it so the next Home shows the first prompt, whatever ran
/// before in this isolate.
void _resetSearchPrompt() {
  while (nextSearchPrompt() != kSearchPrompts.last) {}
}

/// Loads every asset and `Image.network` image of the tree (the bundled artwork) before the capture.
/// Asset images decode off the frame loop, so without this the first frame
/// would depend on timing. Network images fail at once in tests and drop to
/// their bundled fallback, which a further round then loads. Rounds are
/// bounded; each waits on the real decode, never on a clock.
Future<void> _loadImages(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate().toList()) {
        var provider = (element.widget as Image).image;
        if (provider is ResizeImage) provider = provider.imageProvider;
        // Cached network images wait on a sqflite-backed cache that is not
        // available in tests: leave them in their placeholder state.
        if (provider is! AssetImage && provider is! NetworkImage) continue;
        await precacheImage(
          (element.widget as Image).image,
          element,
          onError: (_, __) {},
        );
      }
    });
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

/// The first cached network image of an isolate opens the image cache's sqflite
/// database, which does not exist in tests, and the failure surfaces as an
/// uncaught error in whichever test is running. Resolving one here, inside a
/// guarded zone, takes that failure once where it can be caught; product
/// images then stay in their placeholder state in every test, the same way.
Future<void> _settleImageCache() async {
  final done = Completer<void>();
  void finish() {
    if (!done.isCompleted) done.complete();
  }

  void resolve() {
    CachedNetworkImageProvider('https://images.invalid/x')
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener(
            (_, __) => finish(),
            onError: (_, __) => finish(),
          ),
        );
  }

  runZonedGuarded(resolve, (_, __) => finish());
  // Bounded wait on the real event loop; the error arrives in a few ms.
  await Future.any<void>(<Future<void>>[
    done.future,
    Future<void>.delayed(const Duration(seconds: 5)),
  ]);
}

/// Registers the icon font the test bundle ships, or icons paint as boxes.
Future<void> _loadMaterialIcons() async {
  final loader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GoldenFileComparator previousComparator;

  setUpAll(() async {
    await loadBundledFonts();
    await _settleImageCache();
    await _loadMaterialIcons();
    previousComparator = goldenFileComparator;
    goldenFileComparator = TolerantGoldenComparator(
      Uri.base.resolve('test/goldens/ui04_typography_goldens_test.dart'),
      tolerance: _tolerance,
    );
  });

  tearDownAll(() {
    goldenFileComparator = previousComparator;
  });

  for (final entry in _screens.entries) {
    final (screen, build) = entry.value;
    for (final phone in _phones) {
      final size = '${phone.width.toInt()}x${phone.height.toInt()}';
      testWidgets(
        'UI-04 $screen $size golden',
        (tester) async {
          tester.view.devicePixelRatio = 3.0;
          tester.view.physicalSize = phone * 3.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          mockPathProvider();

          final store = CatalogStore(database: openTestDatabase());
          addTearDown(store.dispose);
          await store.loadFromAsset();

          final home = await build(store);
          await tester.pumpWidget(
            StoreScope(
              notifier: store,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildLightTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.noScaling),
                  child: child!,
                ),
                home: home,
              ),
            ),
          );
          // Bounded frames: shimmers and carousels never settle.
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await _loadImages(tester);
          expect(tester.takeException(), isNull);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('ui04/${entry.key}_$size.png'),
          );
        },
        tags: ['golden'],
        skip: !Platform.isMacOS,
      );
    }
  }
}
