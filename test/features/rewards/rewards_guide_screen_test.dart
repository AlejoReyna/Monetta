import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
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
        tester, RewardsGuideScreen(reader: _Reader(_summary())),
        size: const Size(390, 1400));
    expect(find.textContaining('184 Monetta'), findsOneWidget);
    expect(find.text('Tu nivel y sus beneficios aún no están disponibles.'),
        findsOneWidget);
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
