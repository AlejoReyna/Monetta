/// An amount of money in one of the currencies the app renders.
///
/// Pure Dart — no Flutter, no codegen. Same rationale as `domain/product.dart`.
library;

enum Currency { mxn, usd }

class Money {
  const Money({required this.amount, required this.currency});

  final double amount;
  final Currency currency;

  String get currencyCode => currency == Currency.mxn ? 'MXN' : 'USD';
}
