import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/personalization/personalization_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import 'package:monetta_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

AccountController _controller(AppDatabase db) => AccountController(
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

Future<CatalogStore> _store(AppDatabase db) async {
  final store = CatalogStore(database: db);
  await store.loadFromAsset();
  return store;
}

Future<void> _pump(
  WidgetTester tester,
  AccountController controller,
  CatalogStore store, {
  bool admin = false,
  VoidCallback? onPartner,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    StoreScope(
      notifier: store,
      child: MaterialApp(
        theme: buildTheme(),
        home: AccountScreen(
          controller: controller,
          canOpenAdmin: () => admin,
          onOpenAdmin: admin ? () {} : null,
          onOpenPartner: onPartner,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ACC-GUIDE rows in the guide order, with the right keys',
      (tester) async {
    final db = openTestDatabase();
    final store = await _store(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    final controller = _controller(db);
    addTearDown(controller.dispose);
    await _pump(tester, controller, store);

    // Identity, then the Rewards card, then the rows (UI v4.1). Direcciones
    // waits for a real address service; Modo Mayoreo and Comparte left.
    final tops = <double>[];
    for (final key in const [
      'account-identity',
      'account-open-rewards-guide',
      'account-open-orders',
      'account-open-favorites',
      'account-open-notifications',
      'account-open-personalization',
      'account-open-contact',
      'account-logout',
    ]) {
      tops.add(tester.getTopLeft(find.byKey(ValueKey(key))).dy);
    }
    expect(tops, orderedEquals([...tops]..sort()), reason: '$tops');
    expect(tops.toSet(), hasLength(tops.length));

    for (final title in [
      'Mis pedidos',
      'Favoritos',
      'Notificaciones',
      'Preferencias',
      'Contacto',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    for (final gone in ['Modo Mayoreo', 'Comparte', 'Métodos de pago']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }

    // What the guide dropped.
    expect(find.text('Mis pedidos recientes'), findsNothing);
    expect(find.byKey(const ValueKey('refresh-orders')), findsNothing);
    expect(find.byKey(const ValueKey('rewards-section')), findsNothing);
    expect(find.text('Privacidad y datos'), findsNothing);
  });

  testWidgets('ACC-GUIDE one «Cerrar sesión» and the legal links stay',
      (tester) async {
    final db = openTestDatabase();
    final store = await _store(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    final controller = _controller(db);
    addTearDown(controller.dispose);
    await _pump(tester, controller, store);

    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('CERRAR SESIÓN'), findsNothing);
    final policy = find.byKey(const ValueKey('account-privacy-policy'));
    expect(policy, findsOneWidget);
    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-delete')), findsOneWidget);
    expect(find.text('Eliminar mi cuenta'), findsOneWidget);
  });

  testWidgets('ACC-GUIDE Preferencias and Contacto open their screens',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = openTestDatabase();
    final store = await _store(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    final controller = _controller(db);
    addTearDown(controller.dispose);
    await _pump(tester, controller, store);

    for (final (key, screen) in [
      ('account-open-personalization', PersonalizationScreen),
      ('account-open-contact', ContactScreen),
    ]) {
      final row = find.byKey(ValueKey(key));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget, reason: key);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('ACC-GUIDE admin and partner hub entries stay when enabled',
      (tester) async {
    final db = openTestDatabase();
    final store = await _store(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    final controller = _controller(db);
    addTearDown(controller.dispose);
    await _pump(tester, controller, store, admin: true, onPartner: () {});
    expect(find.byKey(const ValueKey('open-owner-admin')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-open-partner')), findsOneWidget);
  });

  group('ACC-GUIDE Rewards row follows the account (invariant 9)', () {
    Account accountOf(String id) => Account(
          localAccountId: id,
          shopifyCustomerId: 'gid://shopify/Customer/$id',
          email: '$id@example.com',
          displayName: 'Cuenta $id',
          authProvider: 'shopify',
          createdAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026),
        );

    Future<(AccountController, _GatedReader)> mount(
      WidgetTester tester,
    ) async {
      final db = openTestDatabase();
      final store = await _store(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      final controller = _controller(db)..account = accountOf('A');
      addTearDown(controller.dispose);
      final reader = _GatedReader();
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        StoreScope(
          notifier: store,
          child: MaterialApp(
            theme: buildTheme(),
            home: AccountScreen(controller: controller, rewardsReader: reader),
          ),
        ),
      );
      await tester.pump();
      return (controller, reader);
    }

    String balance(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('account-rewards-balance')))
        .data!;

    // The answer is delivered in a microtask, then the frame paints it.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    void switchTo(AccountController controller, Account? account) {
      controller.account = account;
      // The controller notifies on every login, logout and switch.
      controller.notifyListeners();
    }

    testWidgets('a late answer of A, after the switch to B, is never painted',
        (tester) async {
      final (controller, reader) = await mount(tester);
      expect(reader.calls, 1);
      expect(balance(tester), 'Consultando tu saldo…');

      switchTo(controller, accountOf('B'));
      await tester.pump();
      expect(reader.calls, 2, reason: 'B asks for its own balance');

      reader.complete(0, 11100); // A answers late.
      await settle(tester);
      expect(balance(tester), 'Consultando tu saldo…');
      expect(find.textContaining('111'), findsNothing);

      reader.complete(1, 22200); // B's own answer.
      await settle(tester);
      expect(balance(tester), contains('222'));
    });

    testWidgets('switching A to B clears A\'s balance at once, then shows B\'s',
        (tester) async {
      final (controller, reader) = await mount(tester);
      reader.complete(0, 18400);
      await settle(tester);
      expect(balance(tester), contains('184'));

      switchTo(controller, accountOf('B'));
      await tester.pump();
      expect(balance(tester), 'Consultando tu saldo…');
      expect(find.textContaining('184'), findsNothing);
      expect(reader.calls, 2);

      reader.complete(1, 5000);
      await settle(tester);
      expect(balance(tester), contains('50'));
      expect(find.textContaining('184'), findsNothing);
    });

    testWidgets('after logout no balance of the previous account is shown',
        (tester) async {
      final (controller, reader) = await mount(tester);
      reader.complete(0, 18400);
      await settle(tester);
      expect(balance(tester), contains('184'));

      switchTo(controller, null);
      await tester.pump();
      final shown = find.byKey(const ValueKey('account-rewards-balance'));
      expect(shown, findsNothing);
      expect(find.textContaining('184'), findsNothing);
      expect(reader.calls, 1, reason: 'nobody is signed in: no request');

      // Signing in again never repaints the old amount.
      switchTo(controller, accountOf('B'));
      await tester.pump();
      expect(balance(tester), 'Consultando tu saldo…');
      expect(reader.calls, 2);
    });
  });
}

/// Reader whose answers are released by the test, one `Completer` per call.
class _GatedReader implements RewardsReader {
  final List<Completer<RewardsSummary>> _pending = [];

  int get calls => _pending.length;

  void complete(int index, int availableCents) {
    _pending[index].complete(
      RewardsSummary(
        redemptionEnabled: false,
        availableCents: availableCents,
        pendingCents: 0,
        reservedCents: 0,
        nextExpiry: null,
        asOf: DateTime.utc(2026, 9, 14),
        firstPurchaseEnabled: false,
        reviewEnabled: false,
        referralEnabled: false,
      ),
    );
  }

  @override
  Future<RewardsSummary> summary() {
    final completer = Completer<RewardsSummary>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<({List<RewardsMovement> movements, String? nextCursor})>
      activity() async =>
          (movements: const <RewardsMovement>[], nextCursor: null);

  @override
  Future<OrderRewardsState> orderRewards(String shopifyOrderId) {
    throw UnimplementedError();
  }
}
