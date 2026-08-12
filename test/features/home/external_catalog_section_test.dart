import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/home/external_catalog_section.dart';

CatalogItem _coachItem() => CatalogItem(
      sourceScopedId: 'coach_us:C1',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'Tabby Shoulder Bag 26',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      price: const Money(amount: 350, currency: Currency.usd),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://www.coach.com/tabby-shoulder-bag-26/C8879.html',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 10, 9),
      purchaseMode: PurchaseMode.externalResearch,
    );

CatalogItem _mkItem() => CatalogItem(
      sourceScopedId: 'michael_kors_us:M1',
      source: CatalogSourceType.michaelKorsUs,
      merchant: 'Michael Kors',
      title: 'Jet Set Crossbody',
      brand: 'Michael Kors',
      category: 'Handbags',
      imageUrl: null,
      price: const Money(amount: 228, currency: Currency.usd),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://www.michaelkors.com/jet-set-crossbody/_/R-1',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 10, 9),
      purchaseMode: PurchaseMode.externalResearch,
    );

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  test('provides badges and CTAs for every external source', () {
    expect(externalSourceBadge(CatalogSourceType.guessUs), 'GUESS US · USD');
    expect(externalCtaLabel(CatalogSourceType.guessUs), 'Ver en GUESS');
    expect(
      externalSourceBadge(CatalogSourceType.steveMaddenUs),
      'Steve Madden US · USD',
    );
    expect(
      externalCtaLabel(CatalogSourceType.steveMaddenUs),
      'Ver en Steve Madden',
    );
  });

  testWidgets('renders nothing when there are no items', (tester) async {
    await _pump(
      tester,
      const ExternalCatalogSection(items: [], generatedAt: null),
    );
    expect(find.byType(ExternalCatalogSection), findsOneWidget);
    expect(find.text('Ver en Coach'), findsNothing);
  });

  testWidgets(
      'shows the source badge, price with currency code, and CTA per source',
      (tester) async {
    await _pump(
      tester,
      ExternalCatalogSection(
        items: [_coachItem(), _mkItem()],
        generatedAt: DateTime.utc(2026, 8, 10, 9),
      ),
    );

    expect(find.textContaining('COACH US · USD'), findsOneWidget);
    expect(find.textContaining('MICHAEL KORS US · USD'), findsOneWidget);
    expect(find.text('\$350 USD'), findsOneWidget);
    expect(find.text('\$228 USD'), findsOneWidget);
    expect(find.text('Ver en Coach'), findsOneWidget);
    expect(find.text('Ver en Michael Kors'), findsOneWidget);
  });

  testWidgets('shows the owner-procurement and internal-prototype disclosures',
      (tester) async {
    await _pump(
      tester,
      ExternalCatalogSection(
        items: [_coachItem()],
        generatedAt: DateTime.utc(2026, 8, 10, 9),
      ),
    );

    expect(find.text('Candidato de compra · origen EE. UU.'), findsOneWidget);
    expect(
      find.textContaining('Candidatos para compra manual del propietario'),
      findsOneWidget,
    );
  });

  testWidgets('never shows a wishlist heart or add-to-bag affordance',
      (tester) async {
    await _pump(
      tester,
      ExternalCatalogSection(items: [_coachItem()], generatedAt: null),
    );

    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.textContaining('bolsa'), findsNothing); // "Agregar a la bolsa"
    expect(find.textContaining('WHATSAPP'), findsNothing);
  });

  testWidgets(
      'tapping a card opens the merchant URL via the injected opener, not in-app',
      (tester) async {
    Uri? openedUri;
    await _pump(
      tester,
      ExternalCatalogSection(
        items: [_coachItem()],
        generatedAt: null,
        openLink: (uri) async {
          openedUri = uri;
          return true;
        },
      ),
    );

    await tester.ensureVisible(find.text('Ver en Coach'));
    await tester.tap(find.text('Ver en Coach'));
    await tester.pumpAndSettle();

    expect(
      openedUri,
      Uri.parse('https://www.coach.com/tabby-shoulder-bag-26/C8879.html'),
    );
  });

  testWidgets(
      'renders the neutral "Consultar precio" label instead of \$0 when the price is unknown',
      (tester) async {
    final noPriceItem = CatalogItem(
      sourceScopedId: 'coach_us:C2',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'Mystery Item',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      price: null,
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://www.coach.com/products/mystery/C2.html',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 10, 9),
      purchaseMode: PurchaseMode.externalResearch,
    );

    await _pump(
      tester,
      ExternalCatalogSection(items: [noPriceItem], generatedAt: null),
    );

    expect(find.text('Consultar precio'), findsOneWidget);
    expect(find.textContaining('\$0'), findsNothing);
  });

  testWidgets(
      'refuses to open an invalid detail URL (wrong host for the declared source)',
      (tester) async {
    final spoofedItem = CatalogItem(
      sourceScopedId: 'coach_us:C3',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'Spoofed Item',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      price: const Money(amount: 100, currency: Currency.usd),
      availability: CatalogAvailability.inStock,
      // Host does not belong to CatalogSourceType.coachUs.
      detailUrl: 'https://www.michaelkors.com/products/spoofed/C3.html',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 10, 9),
      purchaseMode: PurchaseMode.externalResearch,
    );

    var openCalled = false;
    await _pump(
      tester,
      ExternalCatalogSection(
        items: [spoofedItem],
        generatedAt: null,
        openLink: (uri) async {
          openCalled = true;
          return true;
        },
      ),
    );

    await tester.ensureVisible(find.text('Spoofed Item'));
    await tester.tap(find.text('Spoofed Item'));
    await tester.pumpAndSettle();

    expect(openCalled, isFalse);
    expect(find.textContaining('Enlace no válido'), findsOneWidget);
  });

  testWidgets(
      'tapping anywhere on the card (not just the CTA) also opens the link',
      (tester) async {
    var openCount = 0;
    await _pump(
      tester,
      ExternalCatalogSection(
        items: [_coachItem()],
        generatedAt: null,
        openLink: (uri) async {
          openCount++;
          return true;
        },
      ),
    );

    await tester.ensureVisible(find.text('Tabby Shoulder Bag 26'));
    await tester.tap(find.text('Tabby Shoulder Bag 26'));
    await tester.pumpAndSettle();

    expect(openCount, 1);
  });
}
