// v4.1 G02: no retired sharing/visual settings; real routes and private balance.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/catalog/brands_screen.dart';
import 'package:monetta_app/features/navigation/monetta_side_menu.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import '../catalog/v41_discovery_fixture.dart';
import '../catalog/v41_discovery_test.dart' show mountDiscovery, tapVisible;
import '../catalog/v41_discovery_capture_test.dart' show fixtureMenu;

class _Identity extends AccountController {
  _Identity(AppDatabase db)
      : super(
          accountStore: AccountStore(db),
          deviceStore: DeviceStore(db),
          orderHistoryRepository: OrderHistoryRepository(
            store: OrderSummaryStore(db),
            config: AccountsOrdersConfig.disabled,
          ),
          deviceId: 'fixture-device',
        );
  void change(String? id) {
    account = id == null
        ? null
        : Account(
            localAccountId: id,
            email: '$id@fixture.invalid',
            displayName: id,
            authProvider: 'monetta',
            createdAt: DateTime.utc(2026),
            lastSeenAt: DateTime.utc(2026),
          );
    notifyListeners();
  }
}

class _Reader implements RewardsReader {
  final pending = <Completer<RewardsSummary>>[];
  @override
  Future<RewardsSummary> summary() {
    final next = Completer<RewardsSummary>();
    pending.add(next);
    return next.future;
  }

  @override
  Future<({List<RewardsMovement> movements, String? nextCursor})> activity() =>
      throw UnimplementedError();
  @override
  Future<OrderRewardsState> orderRewards(String _) =>
      throw UnimplementedError();
}

RewardsSummary _summary(int amount) => RewardsSummary.fromJson({
      'balance': {
        'availableCents': amount,
        'pendingCents': 0,
        'reservedCents': 0,
        'asOf': '2026-11-11T00:00:00Z',
      },
    });
void main() {
  testWidgets(
      'sidebar all-brands opens real directory, explicit close preserves origin',
      (tester) async {
    final store = await discoveryStore();
    final key = GlobalKey<ScaffoldState>();
    await mountDiscovery(
      tester,
      Scaffold(key: key, drawer: fixtureMenu(), body: const Text('Origin')),
      store,
    );
    key.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('side-menu-share')), findsNothing);
    expect(find.byKey(const Key('side-menu-appearance')), findsNothing);
    expect(find.text('VIP'), findsNothing);
    await tapVisible(tester, find.byKey(const Key('side-menu-brands')));
    expect(find.byType(BrandsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Origin'), findsOneWidget);
    key.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('side-menu-close')));
    expect(key.currentState!.isDrawerOpen, isFalse);
  });
  testWidgets(
      'sidebar scroll reaches Mayoreo after brands and labeled social controls at 200%',
      (tester) async {
    final store = await discoveryStore();
    await mountDiscovery(
      tester,
      Scaffold(body: fixtureMenu()),
      store,
      scale: 2,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('side-menu-wholesale')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    final brands = find.byKey(const Key('side-menu-brands'));
    expect(
      tester.getTopLeft(brands).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('side-menu-wholesale'))).dy,
      ),
    );
    for (final id in ['instagram', 'tiktok', 'facebook']) {
      await tester.scrollUntilVisible(
        find.byKey(Key('side-menu-social-$id')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(
        find.byKey(Key('side-menu-social-$id')).hitTestable(),
        findsOneWidget,
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('side-menu-whatsapp')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'late A response cannot replace B balance; logout immediately removes private state',
      (tester) async {
    final db = openTestDatabase();
    final identity = _Identity(db);
    final reader = _Reader();
    addTearDown(() async {
      identity.dispose();
      await db.close();
    });
    identity.change('A');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: SidebarBalance(controller: identity, reader: reader),
        ),
      ),
    );
    identity.change('B');
    await tester.pump();
    reader.pending[1].complete(_summary(45600));
    await tester.pumpAndSettle();
    expect(find.text(r'$456 Monetta'), findsOneWidget);
    reader.pending[0].complete(_summary(12300));
    await tester.pumpAndSettle();
    expect(find.text(r'$123 Monetta'), findsNothing);
    identity.change(null);
    await tester.pumpAndSettle();
    expect(find.text(r'$456 Monetta'), findsNothing);
  });
}
