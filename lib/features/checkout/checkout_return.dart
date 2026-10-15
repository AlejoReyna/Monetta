/// What Monetta can say after Shopify Checkout Sheet Kit returns.
///
/// The kit reports only completed, cancelled, or failed. It does not include
/// a decline reason, and this file never invents one. MON-UX-03-DUP looks for
/// an order from this checkout before another payment attempt.
library;

import '../../data/shopify/cart/checkout_launcher.dart';

/// Proposed poll cadence for MON-UX-03-DUP. Not a measured SLA.
const Duration kCheckoutOrderLookupInterval = Duration(seconds: 3);

/// Proposed upper bound for MON-UX-03-DUP. Not a measured SLA.
const Duration kCheckoutOrderLookupTimeout = Duration(seconds: 30);

/// PM-approved titles. Use verbatim.
const String kCheckoutReturnPaymentNotCompletedTitle = 'No se completó tu pago';

const String kCheckoutReturnSheetDidNotOpenTitle = 'No pudimos abrir el pago';

const String kCheckoutReturnReviewingTitle = 'Estamos revisando tu pago';

/// Body copy is not defined in repo docs or specs.
const String kCheckoutReturnPaymentNotCompletedBodyTodo =
    'TODO(designer): texto secundario de «No se completó tu pago».';

const String kCheckoutReturnSheetDidNotOpenBodyTodo =
    'TODO(designer): texto secundario de «No pudimos abrir el pago».';

const String kCheckoutReturnReviewingBodyTodo =
    'TODO(designer): texto secundario de «Estamos revisando tu pago».';

/// A distinct retry label is not defined. The existing pay action stays the
/// control; this placeholder is for the designer.
const String kCheckoutReturnRetryCtaTodo =
    'TODO(designer): etiqueta del CTA para reintentar el pago.';

enum CheckoutReturnKind {
  completed,
  sheetDidNotOpen,
  paymentNotConfirmed,
}

enum CheckoutReturnPhase {
  reviewing,
  paymentNotCompleted,
  sheetDidNotOpen,
}

/// Cart and checkout tokens for the attempt that just returned.
///
/// Stringification is redacted. These values are bearer-like and must not be
/// logged, shown, or sent anywhere except an order-source comparison.
final class CheckoutAttemptIdentity {
  const CheckoutAttemptIdentity({this.cartToken, this.checkoutToken});

  final String? cartToken;
  final String? checkoutToken;

  bool get canMatch => _usable(cartToken) || _usable(checkoutToken);

  @override
  String toString() => 'CheckoutAttemptIdentity(<redacted>)';
}

/// An order row from an existing source.
///
/// [cartToken] and [checkoutToken] stay null unless that source actually
/// returned them. Customer Account orders and `GET /customers/me/orders` do
/// not, today.
final class CheckoutSourcedOrder {
  const CheckoutSourcedOrder({
    required this.id,
    this.displayNumber,
    this.cartToken,
    this.checkoutToken,
  });

  final String id;
  final String? displayNumber;
  final String? cartToken;
  final String? checkoutToken;

  @override
  String toString() => 'CheckoutSourcedOrder(id: $id, tokens: <redacted>)';
}

final class CheckoutOrderMatch {
  const CheckoutOrderMatch({
    required this.orderId,
    this.displayNumber,
  });

  final String orderId;
  final String? displayNumber;
}

abstract interface class CheckoutOrderLookup {
  /// The order created from [attempt], or null when this read found none.
  ///
  /// A null result is not proof the order will never exist. Callers poll.
  Future<CheckoutOrderMatch?> findOrder(CheckoutAttemptIdentity attempt);
}

sealed class CheckoutReturnDecision {
  const CheckoutReturnDecision();
}

final class CheckoutReturnCompleted extends CheckoutReturnDecision {
  const CheckoutReturnCompleted();
}

final class CheckoutReturnSheetDidNotOpen extends CheckoutReturnDecision {
  const CheckoutReturnSheetDidNotOpen();
}

final class CheckoutOrderFound extends CheckoutReturnDecision {
  const CheckoutOrderFound(this.match);

  final CheckoutOrderMatch match;
}

final class CheckoutOrderNotFound extends CheckoutReturnDecision {
  const CheckoutOrderNotFound();
}

typedef CheckoutOrderClock = DateTime Function();
typedef CheckoutOrderDelay = Future<void> Function(Duration duration);

CheckoutAttemptIdentity checkoutAttemptFromCart({
  required String? cartId,
  required String? checkoutUrl,
}) {
  return CheckoutAttemptIdentity(
    cartToken: cartTokenFromShopifyCartId(cartId),
    checkoutToken: checkoutTokenFromCheckoutUrl(checkoutUrl),
  );
}

/// Token embedded in a Storefront cart GID (`gid://shopify/Cart/{token}`).
///
/// A `?key=` suffix is stripped. The key is not the token.
String? cartTokenFromShopifyCartId(String? cartId) {
  if (cartId == null) return null;
  final trimmed = cartId.trim();
  if (trimmed.isEmpty) return null;
  const prefix = 'gid://shopify/Cart/';
  final raw =
      trimmed.startsWith(prefix) ? trimmed.substring(prefix.length) : trimmed;
  final token = raw.split('?').first.trim();
  if (token.isEmpty) return null;
  return token;
}

/// Last path segment of the checkout URL (`/cart/c/{token}`, `/checkouts/…`).
///
/// Query values, including `key`, are not part of the token.
String? checkoutTokenFromCheckoutUrl(String? checkoutUrl) {
  if (checkoutUrl == null) return null;
  final trimmed = checkoutUrl.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  final segments = [
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (segments.isEmpty) return null;
  final token = segments.last.trim();
  if (token.isEmpty) return null;
  return token;
}

/// Sheet-open failures never reached a payable checkout.
///
/// `configuration` and `unavailable` are raised when the sheet cannot be
/// presented or loaded (missing bridge, bad URL, no presenter, present
/// threw, Checkout Kit `checkoutUnavailable`). Cancelled, expired, already
/// completed, invalid, and unknown results come back from a checkout the
/// shopper may have tried to pay, so they must be reconciled.
CheckoutReturnKind classifyCheckoutResult(CheckoutResult result) {
  return switch (result) {
    CheckoutCompleted() => CheckoutReturnKind.completed,
    CheckoutCancelled() => CheckoutReturnKind.paymentNotConfirmed,
    CheckoutFailed(:final code) => switch (code) {
        CheckoutFailureCode.configuration ||
        CheckoutFailureCode.unavailable =>
          CheckoutReturnKind.sheetDidNotOpen,
        CheckoutFailureCode.cartExpired ||
        CheckoutFailureCode.cartCompleted ||
        CheckoutFailureCode.invalidCart ||
        CheckoutFailureCode.unknown =>
          CheckoutReturnKind.paymentNotConfirmed,
      },
  };
}

/// First order whose checkout or cart token equals this attempt.
///
/// Any order counts, paid or not. Without a token on both sides there is
/// no match — a newer order is not assumed to be this checkout.
CheckoutOrderMatch? matchCheckoutOrder(
  CheckoutAttemptIdentity attempt,
  Iterable<CheckoutSourcedOrder> orders,
) {
  if (!attempt.canMatch) return null;
  for (final order in orders) {
    if (_tokensOverlap(attempt, order)) {
      return CheckoutOrderMatch(
        orderId: order.id,
        displayNumber: order.displayNumber,
      );
    }
  }
  return null;
}

/// Classifies [result]. Payment-unconfirmed results poll [lookup] until an
/// order matches or [timeout] elapses. A sheet that did not open does not
/// poll: no payment attempt was presented.
Future<CheckoutReturnDecision> decideCheckoutReturn({
  required CheckoutResult result,
  required CheckoutOrderLookup lookup,
  required CheckoutAttemptIdentity attempt,
  Duration interval = kCheckoutOrderLookupInterval,
  Duration timeout = kCheckoutOrderLookupTimeout,
  CheckoutOrderClock clock = DateTime.now,
  CheckoutOrderDelay delay = _defaultDelay,
  bool Function()? isCancelled,
}) async {
  return switch (classifyCheckoutResult(result)) {
    CheckoutReturnKind.completed => const CheckoutReturnCompleted(),
    CheckoutReturnKind.sheetDidNotOpen => const CheckoutReturnSheetDidNotOpen(),
    CheckoutReturnKind.paymentNotConfirmed => resolvePaymentReturn(
        lookup: lookup,
        attempt: attempt,
        interval: interval,
        timeout: timeout,
        clock: clock,
        delay: delay,
        isCancelled: isCancelled,
      ),
  };
}

/// Polls immediately, then every [interval], through [timeout] inclusive.
///
/// A lookup error is not evidence that no order exists; polling continues
/// until the window ends. [isCancelled] stops the loop without a decision
/// the UI should treat as "not found".
Future<CheckoutReturnDecision> resolvePaymentReturn({
  required CheckoutOrderLookup lookup,
  required CheckoutAttemptIdentity attempt,
  Duration interval = kCheckoutOrderLookupInterval,
  Duration timeout = kCheckoutOrderLookupTimeout,
  CheckoutOrderClock clock = DateTime.now,
  CheckoutOrderDelay delay = _defaultDelay,
  bool Function()? isCancelled,
}) async {
  final started = clock();
  while (true) {
    if (isCancelled?.call() == true) {
      return const CheckoutOrderNotFound();
    }
    CheckoutOrderMatch? match;
    try {
      match = await lookup.findOrder(attempt);
    } on Object {
      match = null;
    }
    if (match != null) return CheckoutOrderFound(match);
    final elapsed = clock().difference(started);
    if (elapsed >= timeout) return const CheckoutOrderNotFound();
    final remaining = timeout - elapsed;
    final wait = remaining < interval ? remaining : interval;
    if (wait <= Duration.zero) return const CheckoutOrderNotFound();
    await delay(wait);
  }
}

bool _tokensOverlap(
  CheckoutAttemptIdentity attempt,
  CheckoutSourcedOrder order,
) {
  return _sameToken(attempt.cartToken, order.cartToken) ||
      _sameToken(attempt.checkoutToken, order.checkoutToken) ||
      _sameToken(attempt.cartToken, order.checkoutToken) ||
      _sameToken(attempt.checkoutToken, order.cartToken);
}

bool _sameToken(String? left, String? right) {
  if (left == null || right == null) return false;
  final a = left.trim();
  final b = right.trim();
  return a.isNotEmpty && a == b;
}

bool _usable(String? value) => value != null && value.trim().isNotEmpty;

Future<void> _defaultDelay(Duration duration) => Future<void>.delayed(duration);
