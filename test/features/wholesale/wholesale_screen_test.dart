import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/wholesale/wholesale_content.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';
import 'package:monetta_app/main.dart';
import '../../support/client_guide_capture.dart';

void main() {
  test('quote asks for terms without pre-accepting amounts or minimums', () {
    final uri = wholesaleQuoteUri();
    expect(uri.host, 'wa.me');
    expect(uri.queryParameters['text'], isNot(contains(r'$800')));
    expect(uri.queryParameters['text'], isNot(contains('3 modelos')));
    expect(uri.queryParameters['text'], contains('condiciones vigentes'));
  });

  for (final (size, scale, brightness) in [
    (const Size(390, 1100), 1.0, Brightness.light),
    (const Size(320, 568), 2.0, Brightness.light),
    (const Size(834, 1194), 1.0, Brightness.light),
    (const Size(390, 1100), 1.0, Brightness.dark),
  ]) {
    testWidgets(
        'wholesale placeholders, continuity and links at $size / $scale / $brightness',
        (tester) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      final opened = <Uri>[];
      await pumpClientGuide(
        tester,
        StoreScope(
          notifier: store,
          child: WholesaleScreen(
            openUri: (uri) async {
              opened.add(uri);
              return false;
            },
          ),
        ),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      expect(find.text('MAYOREO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (scale == 1) {
        await captureClientGuide(
          tester,
          'wholesale-${size.width.toInt()}-${brightness.name}',
        );
      }
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text(WholesalePresentation.minimum),
        300,
        scrollable: scroll,
      );
      expect(find.text(WholesalePresentation.minimum), findsOneWidget);
      expect(find.textContaining(r'$800'), findsNothing);
      final catalog = find.byKey(const ValueKey('wholesale-catalog-perfume'));
      await tester.scrollUntilVisible(catalog, 300, scrollable: scroll);
      await tester.ensureVisible(catalog);
      await tester.pumpAndSettle();
      // Inspect the existing collection route even with an empty local catalog.
      await tester.tap(catalog);
      await tester.pumpAndSettle();
      final collection =
          tester.widget<CollectionScreen>(find.byType(CollectionScreen));
      expect(collection.filter.category, 'perfume');
      await tester.pageBack();
      await tester.pumpAndSettle();
      final quote = find.byKey(const ValueKey('wholesale-quote-bottom'));
      await tester.scrollUntilVisible(quote, 300, scrollable: scroll);
      await tester.ensureVisible(quote);
      await tester.pumpAndSettle();
      if (scale == 1) {
        await captureClientGuide(
          tester,
          'wholesale-continuity-${size.width.toInt()}-${brightness.name}',
        );
      }
      await tester.tap(quote);
      await tester.pumpAndSettle();
      expect(opened, [wholesaleQuoteUri()]);
      expect(
        find.text('No se pudo abrir WhatsApp. Intenta de nuevo.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('client-guide-footer')),
        300,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
