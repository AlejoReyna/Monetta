/// Money formatting shared by the storefront screens.
///
/// Moved out of `theme.dart` unchanged; `theme.dart` re-exports these names so
/// existing imports keep working.
library;

import 'package:intl/intl.dart';

import '../domain/money.dart';

/// Matches the store's `money_format` of `$ {{amount}}` in MXN.
final NumberFormat kMoney = NumberFormat.currency(
  locale: 'es_MX',
  symbol: r'$ ',
  decimalDigits: 2,
);

/// The neutral label shown in place of a price line when [Money] is `null` —
/// an unknown price is never rendered as `$0`, which would read as "free."
const String kUnknownPriceLabel = 'Consultar precio';

/// Renders a [Money] with an explicit currency code — `$1,999 MXN`,
/// `$350 USD` — never converted, never inferred. `null` (a genuinely unknown
/// price) renders [kUnknownPriceLabel] rather than being coerced to a number.
/// Used by the full-catalog browser; the other screens keep using [kMoney]
/// unchanged.
String formatCatalogMoney(Money? money) {
  if (money == null) return kUnknownPriceLabel;
  final isWhole = money.amount == money.amount.roundToDouble();
  final formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: isWhole ? 0 : 2,
  );
  return '${formatter.format(money.amount)} ${money.currencyCode}';
}
