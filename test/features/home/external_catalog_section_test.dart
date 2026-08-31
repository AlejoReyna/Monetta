import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/home/external_catalog_section.dart';
import 'package:monetta_app/features/product/external_product_screen.dart';

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

CatalogItem _coachItemWithVariants() => CatalogItem(
      sourceScopedId: 'coach_us:CU068',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'Brooklyn Shoulder Bag 28',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      price: const Money(amount: 295, currency: Currency.usd),
      availability: CatalogAvailability.inStock,
      detailUrl:
          'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068.html',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 12),
      purchaseMode: PurchaseMode.ownerProcurement,
      variants: const [
        CatalogVariant(
          variantId: 'CU068:B4BK',
          sku: 'CU068 B4/BK',
          colorName: 'Brass/Black',
          colorCode: 'B4BK',
          imageUrl: null,
          price: Money(amount: 295, currency: Currency.usd),
          availability: CatalogAvailability.inStock,
          detailUrl:
              'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068-B4%2FBK.html',
        ),
        CatalogVariant(
          variantId: 'CU068:B4TF',
          sku: 'CU068 B4/TF',
          colorName: 'Brass/Toffee',
          colorCode: 'B4TF',
          imageUrl: null,
          price: Money(amount: 206.5, currency: Currency.usd),
          availability: CatalogAvailability.inStock,
          detailUrl:
              'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068%20B4%2FTF.html',
        ),
      ],
    );

CatalogItem _perfumeItem() => CatalogItem(
      sourceScopedId: 'gp_mcallen_perfumes:P1',
      source: CatalogSourceType.gpMcallenPerfumes,
      merchant: 'Gold Palace McAllen',
      title: 'Perfume Eau de Parfum',
      brand: 'Perfumes',
      category: 'Perfumes',
      imageUrl: null,
      price: const Money(amount: 1800, currency: Currency.mxn),
      sourcePrice: const Money(amount: 90, currency: Currency.usd),
      vertical: CatalogVertical.perfumes,
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://www.gpmcallen.com/perfume-eau-de-parfum.html',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 22),
      purchaseMode: PurchaseMode.ownerProcurement,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  testWidgets('renders nothing when there are no items', (tester) async {
    await _pump(
      tester,
      const ExternalCatalogSection(items: [], generatedAt: null),
    );
    expect(find.byType(ExternalCatalogSection), findsOneWidget);
    expect(find.text('Ver en Coach'), findsNothing);
  });

  testWidgets(
      'matches regular cards with normalized title, brand and compact price',
      (tester) async {
    await _pump(
      tester,
      ExternalCatalogSection(
        items: [_coachItem(), _mkItem()],
        generatedAt: DateTime.utc(2026, 8, 10, 9),
      ),
    );

    expect(find.text('COACH'), findsOneWidget);
    expect(find.text('MICHAEL KORS'), findsOneWidget);
    expect(find.text('Bolsa Tabby 26 de hombro'), findsOneWidget);
    expect(find.text('Bolsa Jet Set crossbody'), findsOneWidget);
    expect(find.text('\$350 USD'), findsOneWidget);
    expect(find.text('\$228 USD'), findsOneWidget);
    expect(find.textContaining('coach.com'), findsNothing);
    expect(find.textContaining('Candidato de compra'), findsNothing);
    expect(find.text('Ver en Coach'), findsNothing);
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

    expect(
      find.textContaining('Selección en EE. UU. para compra manual'),
      findsOneWidget,
    );
    expect(find.textContaining('Candidato de compra'), findsNothing);
  });

  testWidgets('separates GP McAllen perfumes from bags and wallets',
      (tester) async {
    await _pump(
      tester,
      ExternalCatalogSection(
        items: [_coachItem(), _perfumeItem()],
        generatedAt: DateTime.utc(2026, 8, 22),
      ),
    );

    expect(find.text('Selección de marcas originales'), findsOneWidget);
    expect(find.text('Perfumes seleccionados'), findsOneWidget);
    expect(find.textContaining('PERFUMERÍA · GP MCALLEN'), findsOneWidget);
  });

  testWidgets('never shows a wishlist heart or add-to-bag affordance',
      (tester) async {
    await _pump(
      tester,
      ExternalCatalogSection(items: [_coachItem()], generatedAt: null),
    );

    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('Agregar a la bolsa'), findsNothing);
    expect(find.textContaining('WHATSAPP'), findsNothing);
  });

  testWidgets('the explicit merchant CTA opens the validated source URL',
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

    await tester.ensureVisible(find.text('Bolsa Tabby 26 de hombro'));
    await tester.tap(find.text('Bolsa Tabby 26 de hombro'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('VER EN COACH'));
    await tester.tap(find.text('VER EN COACH'));
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
      'card opens the in-app description and the merchant CTA still rejects an invalid URL',
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

    await tester.ensureVisible(find.text('Bolsa Spoofed Item'));
    await tester.tap(find.text('Bolsa Spoofed Item'));
    await tester.pumpAndSettle();

    expect(find.byType(ExternalProductScreen), findsOneWidget);
    expect(openCalled, isFalse);

    await tester.tap(find.text('VER EN COACH'));
    await tester.pumpAndSettle();

    expect(openCalled, isFalse);
    expect(find.textContaining('Enlace no válido'), findsOneWidget);
  });

  testWidgets(
      'tapping the card opens its in-app product description, not the merchant site',
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

    await tester.ensureVisible(find.text('Bolsa Tabby 26 de hombro'));
    await tester.tap(find.text('Bolsa Tabby 26 de hombro'));
    await tester.pumpAndSettle();

    expect(openCount, 0);
    expect(find.byType(ExternalProductScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('DESCRIPCIÓN DEL PRODUCTO'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('DESCRIPCIÓN DEL PRODUCTO'), findsOneWidget);
    expect(find.text('VER EN COACH'), findsOneWidget);
  });

  testWidgets('color choices stay in detail and update price and merchant URL',
      (tester) async {
    Uri? openedUri;
    await _pump(
      tester,
      ExternalCatalogSection(
        items: [_coachItemWithVariants()],
        generatedAt: null,
        openLink: (uri) async {
          openedUri = uri;
          return true;
        },
      ),
    );

    expect(find.text('Brass/Black'), findsNothing);
    expect(find.text('\$295 USD'), findsOneWidget);

    await tester.ensureVisible(find.text('Bolsa Brooklyn 28 de hombro'));
    await tester.tap(find.text('Bolsa Brooklyn 28 de hombro'));
    await tester.pumpAndSettle();

    expect(find.byType(ExternalProductScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Brass/Black'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Brass/Black'), findsOneWidget);

    final toffeeChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('detail-CU068:B4TF')),
    );
    toffeeChip.onSelected!(true);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('detail-CU068:B4TF')),
          )
          .selected,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.text('\$206.50 USD'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('\$206.50 USD'), findsOneWidget);
    expect(openedUri, isNull);

    await tester.ensureVisible(find.text('VER EN COACH'));
    await tester.tap(find.text('VER EN COACH'));
    await tester.pumpAndSettle();
    expect(
      openedUri,
      Uri.parse(
        'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068%20B4%2FTF.html',
      ),
    );
  });
}
