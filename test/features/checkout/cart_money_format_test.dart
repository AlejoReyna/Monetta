import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/cart.dart';
import 'package:monetta_app/features/checkout/shopify_cart_summary.dart';

CartMoney _money(String amount) =>
    CartMoney(amount: amount, currencyCode: 'MXN');

void main() {
  group('CHAR-BAG-04 formatCartMoney (presentation of decimal strings)', () {
    const cases = <String, String>{
      '4842.0': r'$ 4,842.00',
      '4842': r'$ 4,842.00',
      '149.5000': r'$ 149.50',
      '0.5': r'$ 0.50',
      '1399': r'$ 1,399.00',
      '1234567.5': r'$ 1,234,567.50',
      // Rounded to cents with string/integer arithmetic, never via double.
      '1399.999': r'$ 1,400.00',
    };

    for (final entry in cases.entries) {
      test('formats ${entry.key} as ${entry.value}', () {
        expect(formatCartMoney(_money(entry.key)), entry.value);
      });
    }

    test('withCurrency appends the currency code', () {
      expect(
        formatCartMoney(_money('4842.0'), withCurrency: true),
        r'$ 4,842.00 MXN',
      );
      expect(
        formatCartMoney(
          const CartMoney(amount: '10', currencyCode: 'USD'),
          withCurrency: true,
        ),
        r'$ 10.00 USD',
      );
    });
  });
}
