import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/restock_request.dart';
import 'package:monetta_app/features/product/restock_request_sheet.dart';

Product _product({required ProductVariant variant}) => Product(
      id: 'gid://shopify/Product/1',
      handle: 'pieza',
      title: 'Bolso Coach',
      vendor: 'Monetta',
      productType: 'Bag',
      tags: const [],
      variants: [variant],
      images: const ['https://cdn.example/bolso.jpg'],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

void main() {
  group('RestockRequestSheet (mocked submit)', () {
    testWidgets('validates email and consent before submit', (tester) async {
      RestockRequestPayload? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showRestockRequestSheet(
                    context,
                    product: _product(
                      variant: const ProductVariant(
                        id: 'gid://shopify/ProductVariant/9',
                        title: 'Negro',
                        price: 1000,
                        available: false,
                        selectedOptions: {'Color': 'Negro'},
                      ),
                    ),
                    variant: const ProductVariant(
                      id: 'gid://shopify/ProductVariant/9',
                      title: 'Negro',
                      price: 1000,
                      available: false,
                      selectedOptions: {'Color': 'Negro'},
                    ),
                    onSubmit: (payload) async {
                      captured = payload;
                      return RestockSubmitResult.created;
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Negro'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('restock-request-submit')));
      await tester.pump();
      expect(captured, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('restock-request-email')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const ValueKey('restock-request-submit')));
      await tester.pump();
      expect(captured, isNull);
      expect(find.text('Escribe un correo válido.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('restock-request-email')),
        'alexis@monetta.mx',
      );
      await tester.tap(find.byKey(const ValueKey('restock-request-consent')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('restock-request-submit')));
      await tester.pump();
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.variant.id, 'gid://shopify/ProductVariant/9');
      expect(captured!.email, 'alexis@monetta.mx');
    });
  });
}
