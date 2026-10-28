import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/navigation/monetta_side_menu.dart';
import 'package:monetta_app/features/rewards/rewards_share_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';
import '../../support/guide_photo_finders.dart';

void main() {
  testWidgets(
      'Rewards share uses the rewards photo with its body and no '
      'button', (tester) async {
    await pumpClientGuide(
      tester,
      const RewardsShareScreen(),
      size: const Size(390, 1200),
    );
    expect(findAssetImage(kGuideShareRewards), findsOneWidget);
    expect(find.text('Comparte'), findsOneWidget);
    expect(find.text('y gana'), findsOneWidget);
    expect(
      find.text(
        'Explora nuestros catálogos, compártelos con el mundo y comienza a '
        'ganar desde tu primer pedido.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(GuideShareEarnBanner),
        matching: find.byType(ButtonStyleButton),
      ),
      findsNothing,
    );
    // The generated phone mockup is gone.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('rewards_phone'),
      ),
      findsNothing,
    );
  });

  testWidgets('side menu card uses the catalog photo and calls onShare', (
    tester,
  ) async {
    var shared = 0;
    await pumpClientGuide(
      tester,
      Scaffold(
        body: MonettaSideMenu(
          onSearch: () {},
          onCatalog: () {},
          onBags: () {},
          onWallets: () {},
          onWatches: () {},
          onPerfumes: () {},
          onBeauty: () {},
          onToggleTheme: () {},
          onAbout: () {},
          onPartner: () {},
          onSupport: () {},
          onShare: () => shared++,
        ),
      ),
      size: const Size(390, 1600),
    );
    expect(find.byKey(const Key('side-menu-share')), findsOneWidget);
    expect(findAssetImage(kGuideShareCatalog), findsOneWidget);
    final button = find.byKey(const Key('side-menu-share-button'));
    expect(button, findsOneWidget);
    // Guide v2: the small «VER CATÁLOGO» pill; the action is still the
    // system share sheet (asserted below).
    expect(button, findsOneWidget);
    expect(tester.widget(button), isA<GuidePillButton>());
    expect(
      find.descendant(of: button, matching: find.text('VER CATÁLOGO')),
      findsOneWidget,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(shared, 1);
  });

  testWidgets('account card uses the catalog photo and opens the share page', (
    tester,
  ) async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
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
        createdAt: DateTime.utc(2026),
        lastSeenAt: DateTime.utc(2026),
      )
      ..ordersStatus = OrderHistoryStatus.empty;
    addTearDown(controller.dispose);

    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: AccountScreen(controller: controller),
      ),
      size: const Size(390, 1800),
    );
    expect(findAssetImage(kGuideShareCatalog), findsOneWidget);
    final button = find.byKey(const ValueKey('account-share-catalog'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.text('VER CATÁLOGO')),
      findsOneWidget,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(RewardsShareScreen), findsOneWidget);
    expect(findAssetImage(kGuideShareRewards), findsOneWidget);
  });
}
