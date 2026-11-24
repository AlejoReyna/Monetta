import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/rewards/rewards_guide_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import 'package:monetta_app/features/rewards/rewards_share_screen.dart';

import '../../support/client_guide_capture.dart';

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

void main() {
  testWidgets(
      'shows real balance and history while unsupported rules stay gated',
      (tester) async {
    await pumpClientGuide(
      tester,
      RewardsGuideScreen(reader: _Reader(_summary())),
      size: const Size(390, 1400),
    );
    expect(find.textContaining('184 Monetta'), findsOneWidget);
    expect(
      find.text('Tu nivel y sus beneficios aún no están disponibles.'),
      findsOneWidget,
    );
    expect(find.text('Compartir catálogo en redes'), findsNothing);
    expect(find.text('Canjear puntos'), findsNothing);
    expect(find.textContaining('pendientes de entrega'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rewards-movements-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay movimientos en tu cuenta.'), findsOneWidget);
  });

  testWidgets('a missing reader does not invent a balance', (tester) async {
    await pumpClientGuide(
      tester,
      const RewardsGuideScreen(),
      size: const Size(390, 900),
    );
    expect(find.text('Monetta Rewards aún no está disponible'), findsOneWidget);
    expect(find.textContaining('320'), findsNothing);
    expect(find.byKey(const ValueKey('rewards-balance')), findsNothing);
  });

  testWidgets('copy and share wait for a real catalog link', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboard = (call.arguments as Map)['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return <String, dynamic>{'text': clipboard};
          case 'Clipboard.hasStrings':
            return <String, dynamic>{'value': clipboard != null};
          default:
            return null;
        }
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final shared = <String>[];
    await pumpClientGuide(
      tester,
      RewardsShareScreen(
        onShare: (text) async => shared.add(text),
        links: const [
          RewardsCatalogLink(
            id: 'bags',
            title: 'Copiar enlace de catálogo de bolsos',
            icon: Icons.shopping_bag_outlined,
          ),
          RewardsCatalogLink(
            id: 'perfumes',
            title: 'Copiar enlace de catálogo de perfumes',
            icon: Icons.water_drop_outlined,
            url: 'https://example.test/perfumes',
          ),
        ],
      ),
      size: const Size(390, 1200),
    );

    await tester.tap(find.byKey(const ValueKey('rewards-copy-bags')));
    await tester.pump();
    expect(find.text('Enlace pendiente de contrato'), findsOneWidget);
    expect(shared, isEmpty);

    await tester.tap(find.byKey(const ValueKey('rewards-copy-perfumes')));
    await tester.pump();
    expect(clipboard, 'https://example.test/perfumes');

    await tester.tap(find.byKey(const ValueKey('rewards-share-perfumes')));
    await tester.pump();
    expect(shared, ['https://example.test/perfumes']);

    await tester.tap(find.byKey(const ValueKey('rewards-share-bags')));
    await tester.pump();
    expect(shared, ['https://example.test/perfumes']);
  });

  testWidgets(
      'v4.3 tier UI shows 270 arc, benefits modal and dedicated movements screen',
      (tester) async {
    final vipSummary = RewardsSummary(
      redemptionEnabled: true,
      availableCents: 11399,
      pendingCents: 1400,
      reservedCents: 0,
      nextExpiry: null,
      asOf: DateTime.utc(2026, 11, 23),
      firstPurchaseEnabled: true,
      reviewEnabled: false,
      referralEnabled: true,
      earnBps: 200,
      tier: const RewardsTier(
        level: 'VIP',
        nextLevel: 'ÉLITE',
        isFinalLevel: false,
        completedPurchases: 5,
        targetPurchases: 10,
        progressFraction: 0.5,
        progressPercent: 50,
        purchaseCountLabel: '5 de 10 compras',
        cashbackBps: 200,
        bonusCents: 10000,
        freeShipping: true,
        introduction:
            'Este nivel lo consigues completando 5 compras con tu cuenta de MONETTA Rewards',
        benefits: [
          RewardsTierBenefit(kind: 'cashback', label: '2% de Cashback'),
          RewardsTierBenefit(
            kind: 'bonus',
            label: 'Bono de \$100 mxn',
            amountCents: 10000,
          ),
          RewardsTierBenefit(
            kind: 'shipping',
            label: 'Envío Gratis en todos tus pedidos',
          ),
        ],
      ),
    );
    await pumpClientGuide(
      tester,
      RewardsGuideScreen(reader: _Reader(vipSummary)),
      size: const Size(390, 900),
    );
    expect(find.text('Tu nivel'), findsOneWidget);
    expect(find.text('MONETTA REWARDS'), findsNothing);
    expect(find.byKey(const ValueKey('rewards-guide-back')), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(
      tester.getCenter(find.text('Tu nivel')).dx,
      closeTo(195, 1.0),
    );
    expect(find.byKey(const ValueKey('rewards-progress-arc')), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('5 de 10 compras'), findsOneWidget);
    expect(find.text('Siguiente nivel: ÉLITE'), findsOneWidget);
    expect(find.text('\$113.99'), findsOneWidget);
    final guideBalance = tester.widget<Text>(
      find.byKey(const ValueKey('rewards-balance-available')),
    );
    expect(guideBalance.style?.fontFamily, kBoutiqueSerifFamily);
    expect(guideBalance.style?.color, MonettaTokens.gold);

    // Open Beneficios del nivel modal
    await tester.tap(find.byKey(const ValueKey('rewards-open-benefits')));
    await tester.pumpAndSettle();
    expect(find.text('Miembro'), findsOneWidget);
    expect(find.text('2% de Cashback'), findsOneWidget);
    expect(find.text('Envío Gratis en todos tus pedidos'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rewards-benefits-dismiss')));
    await tester.pumpAndSettle();

    // Open Ver movimientos screen
    await tester.tap(find.byKey(const ValueKey('rewards-open-movements')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('rewards-movements-empty')),
      findsOneWidget,
    );
    expect(find.text('Aún no hay movimientos'), findsOneWidget);
    final movementsBalance = tester.widget<Text>(
      find.byKey(const ValueKey('rewards-movements-balance')),
    );
    expect(movementsBalance.style?.fontFamily, kBoutiqueSerifFamily);
    expect(movementsBalance.style?.color, MonettaTokens.gold);
  });

  testWidgets(
      'tier header shows centered Tu nivel and keeps only the top bar back button',
      (tester) async {
    final vipSummary = RewardsSummary(
      redemptionEnabled: true,
      availableCents: 11399,
      pendingCents: 0,
      reservedCents: 0,
      nextExpiry: null,
      asOf: DateTime.utc(2026, 11, 23),
      firstPurchaseEnabled: true,
      reviewEnabled: false,
      referralEnabled: true,
      earnBps: 200,
      tier: const RewardsTier(
        level: 'VIP',
        nextLevel: 'ÉLITE',
        isFinalLevel: false,
        completedPurchases: 5,
        targetPurchases: 10,
        progressFraction: 0.5,
        progressPercent: 50,
        purchaseCountLabel: '5 de 10 compras',
        cashbackBps: 200,
        bonusCents: 10000,
        freeShipping: true,
        introduction: 'Nivel VIP',
        benefits: [],
      ),
    );
    await pumpClientGuide(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open-level'),
              onPressed: () => openRewardsGuide(
                context,
                reader: _Reader(vipSummary),
              ),
              child: const Text('Abrir nivel'),
            ),
          ),
        ),
      ),
      size: const Size(390, 900),
    );

    await tester.tap(find.byKey(const ValueKey('open-level')));
    await tester.pumpAndSettle();

    expect(find.text('Tu nivel'), findsOneWidget);
    expect(find.text('MONETTA REWARDS'), findsNothing);
    expect(find.byKey(const ValueKey('rewards-guide-back')), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byTooltip('Volver'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Tu nivel')).dx,
      closeTo(195, 1.0),
    );

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-level')), findsOneWidget);
  });

  for (final (name, size, brightness, widget)
      in <(String, Size, Brightness, Widget)>[
    (
      'rewards',
      const Size(390, 1400),
      Brightness.light,
      RewardsGuideScreen(reader: _Reader(_summary())),
    ),
    (
      'rewards',
      const Size(390, 1400),
      Brightness.dark,
      RewardsGuideScreen(reader: _Reader(_summary())),
    ),
    (
      'rewards',
      const Size(834, 1400),
      Brightness.light,
      RewardsGuideScreen(reader: _Reader(_summary())),
    ),
    (
      'rewards-share',
      const Size(390, 1200),
      Brightness.light,
      const RewardsShareScreen(),
    ),
    (
      'rewards-share',
      const Size(390, 1200),
      Brightness.dark,
      const RewardsShareScreen(),
    ),
    (
      'rewards-share',
      const Size(834, 1400),
      Brightness.light,
      const RewardsShareScreen(),
    ),
  ]) {
    testWidgets('capture $name ${size.width} ${brightness.name}',
        (tester) async {
      await pumpClientGuide(
        tester,
        widget,
        size: size,
        brightness: brightness,
      );
      await captureClientGuide(
        tester,
        '$name-${size.width.toInt()}-${brightness.name}',
      );
      expect(
        find.byType(RewardsGuideScreen).evaluate().length +
            find.byType(RewardsShareScreen).evaluate().length,
        1,
      );
    });
  }
}
