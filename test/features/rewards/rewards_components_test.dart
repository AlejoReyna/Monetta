import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/rewards/rewards_components.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';

RewardsSummary _summary({int available = 18400, int pending = 5400}) =>
    RewardsSummary(
      redemptionEnabled: false,
      availableCents: available,
      pendingCents: pending,
      reservedCents: 0,
      nextExpiry: null,
      asOf: DateTime(2026, 9, 14),
      firstPurchaseEnabled: false,
      reviewEnabled: false,
      referralEnabled: false,
    );

Widget _app(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: child),
    );

void main() {
  test('presentacion en pesos sin calculo autoritativo', () {
    expect(_summary().availableLabel, r'$184 Monetta');
    expect(
      RewardsSummary.fromJson({
        'program': {'redemptionEnabled': false},
        'balance': {'availableCents': 18400, 'pendingCents': 5400},
        'incentives': {
          'firstPurchase': {'enabled': false},
          'review': {'enabled': false},
          'referral': {'enabled': false},
        },
      }).availableCents,
      18400,
    );
  });

  testWidgets('resumen de saldo con estados pendiente/disponible',
      (tester) async {
    await tester.pumpWidget(_app(RewardsBalanceCard(summary: _summary())));
    await tester.pump();
    expect(find.byKey(const ValueKey('rewards-balance-card')), findsOneWidget);
    expect(
      find.text('Tienes \$184 Monetta disponibles'),
      findsOneWidget,
    );
    expect(find.textContaining('pendientes de entrega'), findsOneWidget);
  });

  testWidgets('estimacion de producto identificada como estimacion',
      (tester) async {
    await tester.pumpWidget(
      _app(const RewardsEstimateLabel(estimatedCents: 5400)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('rewards-estimate')), findsOneWidget);
    expect(find.textContaining('no es saldo liberado'), findsOneWidget);
  });

  testWidgets('estado por pedido pendiente y mayoreo excluido', (tester) async {
    await tester.pumpWidget(
      _app(
        OrderRewardsStatus(
          state: OrderRewardsState(
            orderShopifyId: '1234',
            isWholesale: false,
            earnedPendingCents: 5400,
            earnedReleasedCents: 0,
            usedCents: 0,
            state: 'pending',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Se liberan al entregar'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        OrderRewardsStatus(
          state: OrderRewardsState(
            orderShopifyId: 'ws-1',
            isWholesale: true,
            earnedPendingCents: 0,
            earnedReleasedCents: 0,
            usedCents: 0,
            state: 'none',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('no genera Rewards'), findsOneWidget);
  });

  testWidgets('control de canje con limite y error honesto', (tester) async {
    var selected = 0;
    var confirmed = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => RewardsRedemptionControl(
            quote: RewardsQuote(
              quoteId: 'q1',
              cartRevision: 'rev-1',
              subtotalEligibleCents: 90000,
              availableCents: 18400,
              maxAllowedCents: 18000,
              estimatedEarnCents: 2160,
              redemptionEnabled: true,
              expiresAt: DateTime.now().add(const Duration(minutes: 10)),
            ),
            selectedCents: selected,
            onAmountChanged: (value) => setState(() => selected = value),
            onConfirm: () => confirmed = true,
            errorCode: 'exceeds_limit',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('rewards-redemption-control')),
      findsOneWidget,
    );
    expect(find.textContaining('(20%)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rewards-redemption-error')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('rewards-redemption-toggle')));
    await tester.pump();
    expect(selected, 18000);
    expect(confirmed, isFalse);
  });

  testWidgets('control deshabilitado tras bandera', (tester) async {
    await tester.pumpWidget(
      _app(
        RewardsRedemptionControl(
          quote: RewardsQuote(
            quoteId: 'q1',
            cartRevision: 'rev-1',
            subtotalEligibleCents: 90000,
            availableCents: 18400,
            maxAllowedCents: 18000,
            estimatedEarnCents: 0,
            redemptionEnabled: false,
            expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          ),
          selectedCents: 0,
          onAmountChanged: (_) {},
          onConfirm: () {},
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('rewards-redemption-disabled')),
      findsOneWidget,
    );
  });
}
