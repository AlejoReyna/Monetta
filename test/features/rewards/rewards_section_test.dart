import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';

RewardsSummary _summary({
  int available = 18400,
  int pending = 5400,
  RewardsExpiry? expiry,
}) =>
    RewardsSummary(
      redemptionEnabled: true,
      availableCents: available,
      pendingCents: pending,
      reservedCents: 0,
      nextExpiry: expiry,
      asOf: DateTime.utc(2026, 9, 14),
      firstPurchaseEnabled: false,
      reviewEnabled: false,
      referralEnabled: false,
    );

RewardsMovement _movement({
  int id = 1,
  String state = 'available',
  int cents = 5400,
  String? reason,
}) =>
    RewardsMovement(
      id: id,
      type: 'earn_released',
      state: state,
      amountCents: cents,
      orderShopifyId: 'gid://shopify/Order/1',
      reason: reason ?? 'Se liberó al entregar tu pedido #1001',
      createdAt: DateTime.utc(2026, 9, 10),
    );

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('RewardsSection', () {
    testWidgets('shows unavailable when no backend is wired', (tester) async {
      await tester.pumpWidget(
        _host(const RewardsSection(controller: null)),
      );
      await tester.pump();

      expect(
        find.text('Monetta Rewards aún no está disponible'),
        findsOneWidget,
      );
      // Nunca un saldo ficticio.
      expect(find.textContaining('\$184'), findsNothing);
      expect(find.textContaining('320'), findsNothing);
    });

    testWidgets('presents the real balance, pending and expiry', (
      tester,
    ) async {
      final reader = FakeRewardsReader(
        summary: _summary(
          expiry: RewardsExpiry(
            cents: 2000,
            at: DateTime.utc(2027, 9, 10),
          ),
        ),
      );
      await tester.pumpWidget(
        _host(RewardsSection(controller: null, reader: reader)),
      );
      await tester.pumpAndSettle();

      // Componente de F con datos del contrato.
      expect(
        find.byKey(const ValueKey('rewards-balance-card')),
        findsOneWidget,
      );
      expect(find.textContaining('\$184'), findsOneWidget);
      expect(find.textContaining('\$54'), findsOneWidget);
      expect(find.textContaining('10/09/2027'), findsOneWidget);
    });

    testWidgets('movements load on demand with used/expired/reversed', (
      tester,
    ) async {
      final reader = FakeRewardsReader(
        summary: _summary(),
        activity: [
          _movement(
            id: 1,
            state: 'used',
            cents: -18000,
            reason: 'Usaste saldo en tu pedido #1000',
          ),
          _movement(
            id: 2,
            state: 'expired',
            cents: -500,
            reason: 'Venció saldo sin usar',
          ),
          _movement(
            id: 3,
            state: 'reversed',
            cents: -5400,
            reason: 'Se ajustó por devolución del pedido #999',
          ),
        ],
      );
      await tester.pumpWidget(
        _host(RewardsSection(controller: null, reader: reader)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('rewards-movements-toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Usaste saldo en tu pedido #1000'), findsOneWidget);
      expect(find.text('Venció saldo sin usar'), findsOneWidget);
      expect(
        find.text('Se ajustó por devolución del pedido #999'),
        findsOneWidget,
      );
      expect(find.text('Utilizado'), findsWidgets);
      expect(find.text('Expirado'), findsWidgets);
      expect(find.text('Revertido'), findsWidgets);
    });

    testWidgets('transient failure offers retry without faking a balance', (
      tester,
    ) async {
      var calls = 0;
      final failing = _FailingReader(
        onCall: () => calls++,
        error: const RewardsApiError('internal_error'),
      );
      await tester.pumpWidget(
        _host(RewardsSection(controller: null, reader: failing)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No pudimos consultar tu saldo'), findsOneWidget);
      expect(find.textContaining('\$184'), findsNothing);
      expect(calls, 1);
    });

    testWidgets('session error asks to sign in again', (tester) async {
      final reader = FakeRewardsReader(
        failure: const RewardsApiError('unauthenticated'),
      );
      await tester.pumpWidget(
        _host(RewardsSection(controller: null, reader: reader)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tu sesión terminó'), findsOneWidget);
    });

    testWidgets('empty activity says so honestly', (tester) async {
      final reader = FakeRewardsReader(summary: _summary(), activity: []);
      await tester.pumpWidget(
        _host(RewardsSection(controller: null, reader: reader)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('rewards-movements-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.text('Aún no hay movimientos en tu cuenta.'),
        findsOneWidget,
      );
    });
  });

  group('OrderRewardsLine', () {
    testWidgets('renders the order state from F without touching the order',
        (tester) async {
      final reader = FakeRewardsReader(
        perOrder: {
          'gid://shopify/Order/1': const OrderRewardsState(
            orderShopifyId: 'gid://shopify/Order/1',
            isWholesale: false,
            earnedPendingCents: 5400,
            earnedReleasedCents: 0,
            usedCents: 0,
            state: 'pending',
          ),
        },
      );
      await tester.pumpWidget(
        _host(
          const OrderRewardsLine(
            reader: null,
            shopifyOrderId: null,
          ),
        ),
      );
      await tester.pump();
      // Sin identidad no hay nada que consultar.
      expect(
        find.byKey(const ValueKey('order-rewards-status')),
        findsNothing,
      );

      await tester.pumpWidget(
        _host(
          OrderRewardsLine(
            reader: reader,
            shopifyOrderId: 'gid://shopify/Order/1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('order-rewards-status')),
        findsOneWidget,
      );
      expect(find.textContaining('pendientes'), findsOneWidget);
    });

    testWidgets('hides itself when the lookup fails', (tester) async {
      final reader = FakeRewardsReader(
        failure: const RewardsApiError('internal_error'),
      );
      await tester.pumpWidget(
        _host(
          OrderRewardsLine(
            reader: reader,
            shopifyOrderId: 'gid://shopify/Order/1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('order-rewards-status')),
        findsNothing,
      );
    });

    testWidgets('wholesale orders say they do not earn', (tester) async {
      final reader = FakeRewardsReader(
        perOrder: {
          'gid://shopify/Order/9': const OrderRewardsState(
            orderShopifyId: 'gid://shopify/Order/9',
            isWholesale: true,
            earnedPendingCents: 0,
            earnedReleasedCents: 0,
            usedCents: 0,
            state: 'none',
          ),
        },
      );
      await tester.pumpWidget(
        _host(
          OrderRewardsLine(
            reader: reader,
            shopifyOrderId: 'gid://shopify/Order/9',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Este pedido de mayoreo no genera Rewards.'),
        findsOneWidget,
      );
    });
  });
}

class _FailingReader implements RewardsReader {
  _FailingReader({required this.onCall, required this.error});

  final VoidCallback onCall;
  final Object error;

  @override
  Future<RewardsSummary> summary() async {
    onCall();
    throw error;
  }

  @override
  Future<({List<RewardsMovement> movements, String? nextCursor})>
      activity() async {
    onCall();
    throw error;
  }

  @override
  Future<OrderRewardsState> orderRewards(String shopifyOrderId) async {
    onCall();
    throw error;
  }
}
