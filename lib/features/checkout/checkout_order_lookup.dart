/// MON-UX-03-DUP lookup over the order sources the app already has.
///
/// Matching is by checkout token or cart token only. Customer Account
/// `customer.orders` still does not return those fields. `GET /customers/me/orders`
/// does, on each mirror row, and they are passed through when present. A row
/// with null tokens cannot match. This file does not add an endpoint.
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

/// Maps both existing sources.
///
/// Customer Account orders still have no checkout or cart token. Mirror rows
/// pass through [MirroredOrder.checkoutToken] and [MirroredOrder.cartToken].
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
        checkoutToken: order.checkoutToken,
        cartToken: order.cartToken,
      ),
  ];
}
