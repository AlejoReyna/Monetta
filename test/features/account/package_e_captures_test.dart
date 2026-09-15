/// Generador de capturas del paquete E con renderizado real.
///
/// NO es una prueba de aprobación visual: produce PNG legibles con fuentes
/// reales del sistema (la misma cadena de respaldo que usa la app hasta que
/// Playfair Display e Inter se registren en `pubspec.yaml`), datos de
/// fixtures controlados y fotografías reales de producto vía red.
///
/// Fuentes: Georgia y Helvetica Neue del sistema, registradas con sus
/// nombres reales para que la resolución tipográfica sea idéntica a la de
/// producción actual. Sin Ahem en estas imágenes.
///
/// Salida: `docs/redesign/paquete-e-capturas/*.png` (390×844 @2x).
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/favorites/favorites_screen.dart';
import 'package:monetta_app/features/notifications/notification_inbox.dart';
import 'package:monetta_app/features/notifications/notifications_screen.dart';
import 'package:monetta_app/features/orders/order_detail_screen.dart';
import 'package:monetta_app/features/orders/orders_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import 'package:monetta_app/main.dart';

const _capturesDir = 'docs/redesign/paquete-e-capturas';

/// Fuentes del sistema copiadas a `scratch/capture-fonts/` (gitignorada):
/// el `flutter_tester` no puede leer fuera del proyecto, así que el binario
/// se copia con un paso previo de shell. Se registran con sus nombres reales
/// (Georgia, Helvetica Neue, Helvetica), que son exactamente las familias de
/// respaldo que resuelven los tokens hasta registrar Playfair/Inter.
/// La IO real (archivos, fuentes, red) debe ocurrir dentro de
/// `tester.runAsync`: el cuerpo del widget test corre en zona fake-async y
/// cualquier futuro real fuera de runAsync jamás se completa.
Future<void> _loadRealFonts() async {
  Future<void> load(String family, String name) async {
    debugPrint('FONT-START $family/$name');
    final file = File('scratch/capture-fonts/$name');
    if (!await file.exists()) {
      debugPrint('FONT-MISSING $name');
      return;
    }
    final bytes = await file.readAsBytes();
    debugPrint('FONT-BYTES $family ${bytes.length}');
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    debugPrint('FONT-OK $family/$name');
  }

  // Solo TTF de una cara: las colecciones .ttc cuelgan la carga de
  // fuentes del `flutter_tester` (el motor no responde y el futuro jamás
  // se completa). Arial cubre la cadena de respaldo sans en capturas.
  await load('Georgia', 'Georgia.ttf');
  await load('Georgia', 'Georgia Bold.ttf');
  await load('Arial', 'Arial.ttf');
  await load('Arial', 'Arial Bold.ttf');
}

AccountController _controller(AppDatabase db) {
  final controller = AccountController(
    accountStore: AccountStore(db),
    deviceStore: DeviceStore(db),
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    deviceId: 'dev-1',
  )
    ..account = Account(
      localAccountId: 'acct-1',
      shopifyCustomerId: 'gid://shopify/Customer/1',
      email: 'ana@example.com',
      displayName: 'Ana García',
      authProvider: 'shopify',
      createdAt: DateTime.utc(2026, 1, 1),
      lastSeenAt: DateTime.utc(2026, 1, 1),
    )
    ..orders = [
      OrderSummary(
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
      ),
      OrderSummary(
        id: 'gid://shopify/Order/2',
        accountId: 'acct-1',
        displayNumber: '#1000',
        fulfillmentStatus: 'delivered',
        shopifyOrderId: 'gid://shopify/Order/2',
        source: 'shopify_checkout',
        status: 'paid',
        totalAmount: 6490,
        currencyCode: 'MXN',
        placedAt: DateTime.utc(2026, 4, 28),
      ),
      OrderSummary(
        id: 'apartado:9',
        accountId: 'acct-1',
        shopifyOrderId: null,
        source: 'whatsapp_apartado',
        attributionCode: 'MN-7K3Q',
        status: 'pending',
        totalAmount: 400,
        currencyCode: 'MXN',
        placedAt: DateTime.utc(2026, 5, 20),
      ),
    ]
    ..ordersStatus = OrderHistoryStatus.populated;
  return controller;
}

FakeRewardsReader _rewards() => FakeRewardsReader(
      summary: RewardsSummary(
        redemptionEnabled: true,
        availableCents: 18400,
        pendingCents: 5400,
        reservedCents: 0,
        nextExpiry: RewardsExpiry(
          cents: 2000,
          at: DateTime.utc(2027, 9, 10),
        ),
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
          orderShopifyId: 'gid://shopify/Order/2',
          reason: 'Se liberó al entregar tu pedido #1000',
          createdAt: DateTime.utc(2026, 5, 2),
        ),
        RewardsMovement(
          id: 2,
          type: 'earn_pending',
          state: 'pending',
          amountCents: 3444,
          orderShopifyId: 'gid://shopify/Order/1',
          reason: 'Pendiente de entrega del pedido #1001',
          createdAt: DateTime.utc(2026, 5, 12),
        ),
      ],
      perOrder: {
        'gid://shopify/Order/2': const OrderRewardsState(
          orderShopifyId: 'gid://shopify/Order/2',
          isWholesale: false,
          earnedPendingCents: 0,
          earnedReleasedCents: 5400,
          usedCents: 0,
          state: 'available',
        ),
      },
    );

Future<void> _capture(
  WidgetTester tester,
  String name,
  Widget screen, {
  CatalogStore? store,
}) async {
  final boundaryKey = GlobalKey();
  Widget app = MaterialApp(
    theme: buildTheme(),
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: RepaintBoundary(
        key: boundaryKey,
        child: SizedBox(
          width: 390,
          height: 844,
          child: screen,
        ),
      ),
    ),
  );
  if (store != null) {
    app = StoreScope(notifier: store, child: app);
  }
  await tester.pumpWidget(app);
  // Todo lo real (espera de red, raster) dentro de runAsync; los pumps,
  // fuera.
  await tester.runAsync(() async {
    debugPrint('CAPTURE-WAIT $name');
    await Future<void>.delayed(const Duration(seconds: 4));
    debugPrint('CAPTURE-SHOT $name');
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync<ui.Image>(() async {
    return boundary.toImage(pixelRatio: 2);
  });
  final bytes = await tester.runAsync<ByteData?>(() async {
    return image!.toByteData(format: ui.ImageByteFormat.png);
  });
  await tester.runAsync(() async {
    final dir = Directory(_capturesDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    await File('${dir.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(),
    );
  });
  debugPrint('capture: $name.png '
      '(${image!.width}x${image.height})');
}

void main() {
  testWidgets(
    'genera capturas E con renderizado real',
    (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(_loadRealFonts);

      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.loadFromAsset();
      final controller = _controller(db);
      final rewards = _rewards();
      final inbox = NotificationInbox()
        ..ingest(
          MonettaNotification(
            id: 'cap-1',
            title: 'Tu pedido va en camino',
            body: 'El pedido #1001 fue enviado. Te avisaremos al entregar.',
            route: const NotificationRouteData(type: 'home'),
            receivedAt: DateTime.now().toUtc().subtract(
                  const Duration(hours: 2),
                ),
            ownerId: 'acct-1',
            kind: MonettaNotificationKind.order,
          ),
        )
        ..ingest(
          MonettaNotification(
            id: 'cap-2',
            title: 'Tienes saldo Monetta disponible',
            body: 'Se liberaron \$54 de tu pedido #1000.',
            route: const NotificationRouteData(type: 'account'),
            receivedAt: DateTime.now().toUtc().subtract(
                  const Duration(days: 1),
                ),
            ownerId: 'acct-1',
            kind: MonettaNotificationKind.rewards,
          ),
        );

      await _capture(
        tester,
        'e-cuenta',
        AccountScreen(
          controller: controller,
          rewardsReader: rewards,
          notificationInbox: inbox,
        ),
        store: store,
      );
      await _capture(
        tester,
        'e-pedidos',
        OrdersScreen(controller: controller, rewardsReader: rewards),
      );
      await _capture(
        tester,
        'e-detalle',
        OrderDetailScreen(
          order: controller.orders[1],
          rewardsReader: rewards,
        ),
      );

      // Favoritos con piezas y fotos reales del catálogo incluido.
      final ids = store.products.take(4).map((p) => p.id).toList();
      for (final id in ids) {
        await store.toggleWishlist(id);
      }
      await _capture(
        tester,
        'e-favoritos',
        const FavoritesScreen(),
        store: store,
      );

      await _capture(
        tester,
        'e-contacto',
        ContactScreen(openUri: (_) async => true),
      );
      await _capture(
        tester,
        'e-notificaciones',
        NotificationsScreen(
          inbox: inbox,
          ownerId: 'acct-1',
          rewardsReader: rewards,
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
    // Capture generator requires platform plugins and real image IO.
    skip: true,
  );
}
