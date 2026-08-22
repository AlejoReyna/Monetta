import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/editorial_content.dart';
import 'package:monetta_app/features/about/about_monetta_screen.dart';

void main() {
  testWidgets('shows Monetta story and exposes both next actions',
      (tester) async {
    var catalogTaps = 0;
    var partnerTaps = 0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AboutMonettaScreen(
          content: MonettaEditorialContent.fallback.about,
          onOpenCatalog: () => catalogTaps += 1,
          onOpenPartner: () => partnerTaps += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu boutique y proveedor de confianza.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('2023'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2023'), findsOneWidget);

    final partnerButton = find.byKey(const ValueKey('about-open-partner'));
    await tester.scrollUntilVisible(
      partnerButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(partnerButton);
    await tester.pumpAndSettle();
    await tester.tap(partnerButton);
    final catalogButton = find.byKey(const ValueKey('about-open-catalog'));
    await tester.ensureVisible(catalogButton);
    await tester.tap(catalogButton);

    expect(partnerTaps, 1);
    expect(catalogTaps, 1);
  });

  testWidgets('keeps the story readable at tablet width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AboutMonettaScreen(
          content: MonettaEditorialContent.fallback.about,
          onOpenCatalog: () {},
          onOpenPartner: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu boutique y proveedor de confianza.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
