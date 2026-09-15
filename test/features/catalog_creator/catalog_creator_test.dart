import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog_creator/catalog_creator_document.dart';
import 'package:monetta_app/features/catalog_creator/catalog_creator_screen.dart';

Product _product({
  required String id,
  required String title,
  required double price,
  bool available = true,
  String? variantTitle,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    handle: id,
    title: title,
    vendor: 'Monetta',
    productType: 'Bolsa',
    tags: const [],
    variants: [
      ProductVariant(
        id: '$id-v1',
        title: variantTitle ?? 'Default Title',
        price: price,
        available: available,
      ),
    ],
    images: const ['https://monetta.mx/cdn/ejemplo.jpg'],
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('el documento usa precios reales y no inventa enlaces publicos', () {
    final products = [
      _product(id: 'p1', title: 'Bolsa Tabby 26', price: 6490),
      _product(id: 'p2', title: 'Reloj Dorado', price: 1990),
    ];
    final lines = resolveCatalogLines(products, {
      'p1': CatalogSelection(productId: 'p1', variantId: 'p1-v1', quantity: 2),
      'p2': CatalogSelection(productId: 'p2', variantId: 'p2-v1', quantity: 1),
      'fantasma':
          CatalogSelection(productId: 'fantasma', variantId: 'x', quantity: 1),
    });
    expect(lines, hasLength(2));
    expect(catalogTotal(lines), 14970);
    expect(catalogModelCount(lines), 3);
    final text = buildCatalogShareText(title: 'Mi selección', lines: lines);
    expect(text, contains('Bolsa Tabby 26'));
    expect(text, contains('Total estimado'));
    expect(text, isNot(contains('https://')));
    expect(text, contains('confirma por WhatsApp'));
  });

  testWidgets('flujo: seleccionar, cantidad, resumen y compartir explicito',
      (tester) async {
    String? shared;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: CatalogCreatorScreen(
          products: [
            _product(id: 'p1', title: 'Bolsa Tabby 26', price: 6490),
            _product(id: 'p2', title: 'Reloj Dorado', price: 1990),
          ],
          sharer: (text, _) async => shared = text,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Seleccionar dos productos.
    await tester.tap(find.byKey(const ValueKey('catalog-creator-product-p1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('catalog-creator-product-p2')));
    await tester.pump();
    expect(find.byKey(const ValueKey('catalog-creator-total')), findsOneWidget);
    expect(find.textContaining('Total estimado'), findsOneWidget);

    // Cantidad: +1 en p1 (total 2 + 1 modelos).
    await tester.tap(find.byKey(const ValueKey('qty-inc-p1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('qty-p1')), findsOneWidget);

    // Vista previa con precios reales.
    expect(
      find.byKey(const ValueKey('catalog-creator-preview-0')),
      findsOneWidget,
    );

    // Compartir solo por acción explícita.
    await tester.tap(find.byKey(const ValueKey('catalog-creator-share')));
    await tester.pump();
    expect(shared, isNotNull);
    expect(shared, contains('Bolsa Tabby 26'));
  });

  testWidgets('representacion movil de una columna', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: CatalogCreatorScreen(
          products: [_product(id: 'p1', title: 'Bolsa Tabby 26', price: 6490)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('catalog-creator-scroll')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('catalog-creator-steps')), findsOneWidget);
  });
}
