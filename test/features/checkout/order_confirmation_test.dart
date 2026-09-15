import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/checkout/order_confirmation_screen.dart';

Widget _app(Widget child) {
  return MaterialApp(theme: buildTheme(), home: child);
}

void main() {
  test('estimatedDeliveryLabel shows the policy without fabricating dates', () {
    // Sumar días naturales no es días hábiles: la pantalla muestra la
    // política comercial, nunca un rango inventado desde el reloj local.
    final label = estimatedDeliveryLabel(now: DateTime(2026, 5, 9));
    expect(label, '3 a 5 días hábiles');
  });

  testWidgets('confirmation without evidence never invents an order number',
      (tester) async {
    await tester.pumpWidget(_app(const OrderConfirmationScreen()));

    expect(find.text('¡Listo!'), findsOneWidget);
    expect(find.text('Confirmado en Shopify'), findsOneWidget);
    expect(find.textContaining('#MON'), findsNothing);
    expect(find.textContaining('MON12345'), findsNothing);
    expect(find.text('Ver pedido'), findsOneWidget);
    expect(find.text('Seguir comprando'), findsOneWidget);
  });

  testWidgets('confirmation with a real label shows it verbatim',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const OrderConfirmationScreen(
          orderLabel: '#1001',
          email: 'ana@example.com',
        ),
      ),
    );

    expect(find.text('#1001'), findsOneWidget);
    expect(find.textContaining('ana@example.com'), findsOneWidget);
    expect(find.text('3 a 5 días hábiles'), findsOneWidget);
  });

  testWidgets('confirmation never lists payment methods or card fields',
      (tester) async {
    await tester.pumpWidget(
      _app(const OrderConfirmationScreen(orderLabel: '#1001')),
    );

    expect(find.textContaining('Tarjeta'), findsNothing);
    expect(find.textContaining('PayPal'), findsNothing);
    expect(find.textContaining('Oxxo'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });
}
