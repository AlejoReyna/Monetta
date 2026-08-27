import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/product/external_product_screen.dart';

CatalogItem _item({String? imageUrl}) => CatalogItem(
      sourceScopedId: 'coach_us:CU068',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'Brooklyn Shoulder Bag 28',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: imageUrl,
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
          availability: CatalogAvailability.outOfStock,
          detailUrl:
              'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068%20B4%2FTF.html',
        ),
      ],
    );

void main() {
  testWidgets('external product hero also covers the complete viewport',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExternalProductScreen(
          item: _item(imageUrl: 'https://example.com/product.jpg'),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.fit, BoxFit.cover);
  });

  testWidgets(
      'renders product information in-app and updates commerce fields by selected color',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    Uri? openedUri;
    await tester.pumpWidget(
      MaterialApp(
        home: ExternalProductScreen(
          item: _item(),
          openLink: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );

    expect(find.text('Brooklyn Shoulder Bag 28'), findsOneWidget);
    expect(find.text('\$295 USD'), findsOneWidget);
    expect(find.text('DISPONIBLE'), findsOneWidget);
    expect(openedUri, isNull);

    await tester.ensureVisible(find.text('Brass/Toffee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brass/Toffee'));
    await tester.pumpAndSettle();

    expect(find.text('\$206.50 USD'), findsOneWidget);
    expect(find.text('AGOTADO'), findsOneWidget);
    expect(openedUri, isNull);

    await tester.scrollUntilVisible(
      find.text('DESCRIPCIÓN DEL PRODUCTO'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DESCRIPCIÓN DEL PRODUCTO'), findsOneWidget);
    expect(find.text('CU068 B4/TF'), findsOneWidget);

    await tester.tap(find.text('VER EN COACH'));
    await tester.pumpAndSettle();
    expect(
      openedUri,
      Uri.parse(
        'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068%20B4%2FTF.html',
      ),
    );
  });

  testWidgets('never exposes Monetta checkout, wishlist, or WhatsApp actions',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(home: ExternalProductScreen(item: _item())),
    );

    expect(find.textContaining('AGREGAR A LA BOLSA'), findsNothing);
    expect(find.textContaining('WHATSAPP'), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}
