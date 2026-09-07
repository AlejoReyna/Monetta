import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/editorial_content.dart';
import 'package:monetta_app/features/partner/partner_hub_screen.dart';

void main() {
  testWidgets('opens catalogs, shares only client-safe versions, and quotes', (
    tester,
  ) async {
    final launched = <Uri>[];
    final shared = <PartnerCatalog>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PartnerHubScreen(
          content: MonettaEditorialContent.fallback.partner,
          launchUri: (uri) async {
            launched.add(uri);
            return true;
          },
          shareCatalog: (catalog, Rect? _) async => shared.add(catalog),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tu negocio, paso a paso'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tu negocio, paso a paso'), findsOneWidget);
    expect(find.byKey(const ValueKey('share-bags-wholesale')), findsNothing);

    final openButton = find.byKey(const ValueKey('open-bags-suggested'));
    final shareButton = find.byKey(const ValueKey('share-bags-suggested'));
    await tester.scrollUntilVisible(
      openButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(openButton);
    await tester.pumpAndSettle();
    await tester.tap(openButton);
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pump();

    expect(launched.single.host, 'canva.link');
    expect(shared.single.id, 'bags-suggested');

    final catalogQuote = find.byKey(const ValueKey('quote-bags-wholesale'));
    await tester.scrollUntilVisible(
      catalogQuote,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(catalogQuote);
    await tester.pumpAndSettle();
    await tester.tap(catalogQuote);
    await tester.pump();

    expect(
      launched.last.queryParameters['text'],
      contains('Bolsas y carteras'),
    );
    expect(
      launched.last.queryParameters['text'],
      contains('Catálogo: Mayoreo'),
    );

    final quoteButton = find.byKey(const ValueKey('partner-quote-bottom'));
    await tester.scrollUntilVisible(
      quoteButton,
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(quoteButton);
    await tester.pumpAndSettle();
    await tester.tap(quoteButton);
    await tester.pump();

    expect(launched.last.host, 'wa.me');
    expect(launched.last.queryParameters['text'], contains(r'$800 MXN'));
    expect(launched.last.queryParameters['text'], contains('Origen: app'));
  });

  testWidgets('includes reference content without excluded sections', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PartnerHubScreen(
          content: MonettaEditorialContent.fallback.partner,
          launchUri: (_) async => true,
          shareCatalog: (_, __) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('DESCUENTOS DE MAYOREO'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DESCUENTOS DE MAYOREO'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sistema de apartado'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sistema de apartado'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('GRUPOS DE MONETTA'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('GRUPOS DE MONETTA'), findsOneWidget);
    expect(find.text('CALENDARIO DE PEDIDOS'), findsNothing);
    expect(find.text('NUESTROS PRODUCTOS'), findsNothing);
    expect(find.text('REGÍSTRATE'), findsNothing);
  });

  testWidgets('catalog and steps remain responsive at tablet width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PartnerHubScreen(
          content: MonettaEditorialContent.fallback.partner,
          launchUri: (_) async => true,
          shareCatalog: (_, __) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('partner-catalog-bags-wholesale')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });


}
