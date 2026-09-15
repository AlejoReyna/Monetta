import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/wholesale/wholesale_content.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';

Widget _app() => MaterialApp(
      theme: buildLightTheme(),
      home: const WholesaleScreen(),
    );

void main() {
  test('las reglas comerciales no inventan tarifas por tramo', () {
    expect(WholesaleTerms.minModels, 3);
    expect(WholesaleTerms.depositWholesale, r'$800 MXN');
    expect(WholesaleTerms.payOffDays, 20);
    // Sin tabla de tramos: la nota explica cotización por producto.
    expect(WholesaleTerms.volumePricingNote, contains('WhatsApp'));
    expect(WholesaleTerms.volumePricingNote, isNot(contains('12 piezas')));
    expect(WholesaleTerms.rewardsNote, contains('no generan'));
  });

  testWidgets('mayoreo secciona portada, condiciones, volumen, proceso y CTA',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wholesale-scroll')), findsOneWidget);
    expect(
      find.text('Compra desde 3 piezas. Obtén mejores precios.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('wholesale-quote-top')), findsOneWidget);
    for (final section in [
      'Mayoreo sin letras chicas',
      'Compra más, mejora tu precio',
      'De la selección al pedido',
    ]) {
      await tester.scrollUntilVisible(find.text(section), 400);
      await tester.pumpAndSettle();
      expect(find.text(section), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('wholesale-quote-bottom')),
      400,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('wholesale-quote-bottom')),
      findsOneWidget,
    );
    expect(find.textContaining('no generan Monetta Rewards'), findsOneWidget);
  });
}
