import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/checkout/checkout_summary_row.dart';

Future<BoutiquePalette> _pump(
  WidgetTester tester, {
  required bool prominent,
}) async {
  late BoutiquePalette palette;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            palette = context.boutique;
            return CheckoutSummaryRow(
              label: 'Subtotal',
              value: r'$1,250.00',
              prominent: prominent,
            );
          },
        ),
      ),
    ),
  );
  return palette;
}

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets(
      'INV-06 summary row: paints label and value in regular '
      'weights', (tester) async {
    final palette = await _pump(tester, prominent: false);

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text(r'$1,250.00'), findsOneWidget);

    final label = _styleOf(tester, 'Subtotal');
    expect(label.fontSize, 13);
    expect(label.fontWeight, FontWeight.w400);
    expect(label.color, palette.ink);

    final value = _styleOf(tester, r'$1,250.00');
    expect(value.fontSize, 13);
    expect(value.fontWeight, FontWeight.w500);
    expect(value.color, palette.ink);
  });

  testWidgets('INV-06 summary row: prominent raises size and weight',
      (tester) async {
    final palette = await _pump(tester, prominent: true);

    final label = _styleOf(tester, 'Subtotal');
    expect(label.fontSize, 15);
    expect(label.fontWeight, FontWeight.w600);
    expect(label.color, palette.ink);

    final value = _styleOf(tester, r'$1,250.00');
    expect(value.fontSize, 16);
    expect(value.fontWeight, FontWeight.w700);
    expect(value.color, palette.ink);
  });
}
