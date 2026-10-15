/// MON-UX-03-DUP lookup over the order sources the app already has.
///
/// Matching is by checkout token or cart token only. Neither the Customer
/// Account `customer.orders` query nor `GET /customers/me/orders` returns
/// those fields, and `orders_mirror` does not store them. Rows are therefore
/// emitted with null tokens. A match cannot succeed until a source actually
/// carries the token — this file does not add an endpoint or invent one.
library;

import '../../app/account_controller.dart';
import '../../data/repositories/order_history_repository.dart';
import 'checkout_return.dart';

final class AccountCheckoutOrderLookup implements CheckoutOrderLookup {
  AccountCheckoutOrderLookup(this._account);

  final AccountController _account;

  @override
  Future<CheckoutOrderMatch?> findOrder(CheckoutAttemptIdentity attempt) async {
    final snapshot = await _account.loadCheckoutCorrelation();
    return matchCheckoutOrder(
      attempt,
      checkoutSourcedOrdersFrom(snapshot),
    );
  }
}

/// Maps both existing sources. Token fields are left empty on purpose.
List<CheckoutSourcedOrder> checkoutSourcedOrdersFrom(
  OrderCorrelationSnapshot snapshot,
) {
  return [
    for (final order in snapshot.customerOrders)
      CheckoutSourcedOrder(
        id: order.id,
        displayNumber: order.name,
      ),
    for (final order in snapshot.mirroredOrders)
      CheckoutSourcedOrder(
        id: order.shopifyOrderId ?? 'mirror:${order.id}',
      ),
  ];
}
