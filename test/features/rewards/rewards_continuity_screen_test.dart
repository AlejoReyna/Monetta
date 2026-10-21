import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/editorial_content.dart';
import 'package:monetta_app/features/rewards/rewards_continuity_screen.dart';

import '../../support/client_guide_capture.dart';

void main() {
  testWidgets('shares and copies the already published catalogs', (
    tester,
  ) async {
    final shared = <PartnerCatalog>[];
    final copied = <String>[];

    await pumpClientGuide(
      tester,
      RewardsContinuityScreen(
        onShare: (catalog, _) async => shared.add(catalog),
        onCopy: (text) async => copied.add(text),
      ),
      size: const Size(390, 844),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('rewards-continuity-bags')),
    );
    expect(
      find.byKey(const ValueKey('rewards-continuity-bags')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rewards-continuity-perfumes')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('rewards-continuity-share-bags-suggested')),
    );
    await tester.tap(
      find.byKey(const ValueKey('rewards-continuity-share-bags-suggested')),
    );
    await tester.pumpAndSettle();
    expect(shared.single.id, 'bags-suggested');

    await tester.ensureVisible(
      find.byKey(const ValueKey('rewards-continuity-copy-bags-suggested')),
    );
    await tester.tap(
      find.byKey(const ValueKey('rewards-continuity-copy-bags-suggested')),
    );
    await tester.pumpAndSettle();
    expect(copied.single, 'https://canva.link/nd89t2ygievrw3i');
    expect(find.text('Enlace copiado'), findsOneWidget);
  });

  testWidgets('an empty catalog list stays honest', (tester) async {
    await pumpClientGuide(
      tester,
      const RewardsContinuityScreen(catalogs: []),
      size: const Size(390, 844),
    );

    expect(
      find.byKey(const ValueKey('rewards-continuity-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rewards-continuity-share-bags-suggested')),
      findsNothing,
    );
  });

  testWidgets('continuity captures at 390 and 834', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await pumpClientGuide(
        tester,
        RewardsContinuityScreen(
          onShare: (_, __) async {},
          onCopy: (_) async {},
        ),
        size: const Size(390, 844),
        brightness: brightness,
      );
      await captureClientGuide(
        tester,
        'rewards-continuity-390-${brightness.name}',
      );
    }
    await pumpClientGuide(
      tester,
      RewardsContinuityScreen(
        onShare: (_, __) async {},
        onCopy: (_) async {},
      ),
      size: const Size(834, 1112),
    );
    await captureClientGuide(tester, 'rewards-continuity-834-light');
  });

  testWidgets('continuity at 320 / 200% does not overflow', (tester) async {
    await pumpClientGuide(
      tester,
      RewardsContinuityScreen(
        onShare: (_, __) async {},
        onCopy: (_) async {},
      ),
      size: const Size(320, 568),
      textScale: 2,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('rewards-continuity-perfumes')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
