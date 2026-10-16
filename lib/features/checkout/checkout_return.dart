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

/// Stays false even though `GET /customers/me/orders` can return
/// `checkoutToken` and `cartToken`. A 30s miss can still be a slow webhook,
/// so timeout keeps banner 3 until PM/Designer decide otherwise.
const bool kCheckoutTokenCorrelationAvailable = false;

/// Shown with a loading indicator while the lookup window is open.
const String kCheckoutReturnConfirmingText = 'Confirmando tu pago…';

const String kCheckoutReturnPaymentNotCompletedTitle = 'No se completó tu pago';

const String kCheckoutReturnPaymentNotCompletedBody =
    'No se hizo ningún cargo. Tus productos siguen en el carrito.';

const String kCheckoutReturnSheetDidNotOpenTitle = 'No pudimos abrir el pago';

const String kCheckoutReturnSheetDidNotOpenBody =
    'Revisa tu conexión e inténtalo otra vez. Tus productos siguen en el carrito.';

const String kCheckoutReturnReviewingTitle = 'Estamos revisando tu pago';

const String kCheckoutReturnReviewingBody =
    'Si se hizo el cargo, tu pedido aparecerá en Mis pedidos. Para evitar un cobro doble, no vuelvas a pagar todavía.';

const String kCheckoutReturnRetryLabel = 'Intentar de nuevo';

const String kCheckoutReturnViewOrdersLabel = 'Ver mis pedidos';

const String kCheckoutReturnWhatsAppLabel = 'Escríbenos por WhatsApp';

/// DUP-02. Shown before a second checkout while banner 3 is active.
const String kCheckoutDoubleChargeTitle = 'Es posible que ya hayas pagado';

const String kCheckoutDoubleChargeBody =
    'Revisa Mis pedidos antes de pagar otra vez para evitar un cobro doble.';

const String kCheckoutDoubleChargePayAnywayLabel = 'Pagar de todos modos';

enum CheckoutReturnKind {
  completed,
  sheetDidNotOpen,
  paymentNotConfirmed,
}

enum CheckoutReturnPhase {
  /// Lookup in progress. Not a settled banner.
  confirming,

  /// Banner 1. Only after a capable lookup finds no order.
  paymentNotCompleted,

  /// Banner 2. The sheet never opened.
  sheetDidNotOpen,

  /// Banner 3. The outcome is still uncertain.
  reviewing,
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

/// Capable lookup finished with no matching order. Banner 1.
final class CheckoutOrderNotFound extends CheckoutReturnDecision {
  const CheckoutOrderNotFound();
}

/// Timeout or a failed read that cannot prove there was no charge. Banner 3.
final class CheckoutReturnUncertain extends CheckoutReturnDecision {
  const CheckoutReturnUncertain();
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
  bool correlationAvailable = kCheckoutTokenCorrelationAvailable,
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
        correlationAvailable: correlationAvailable,
        clock: clock,
        delay: delay,
        isCancelled: isCancelled,
      ),
  };
}

/// Polls immediately, then every [interval], through [timeout] inclusive.
///
/// A matching order wins even after an earlier failed read. If the window
/// ends without a match, [CheckoutOrderNotFound] is returned only when
/// [correlationAvailable] is true and every read succeeded. A lookup error,
/// or a timeout while correlation is unavailable, is [CheckoutReturnUncertain]:
/// absence of a match is not proof that no charge happened.
Future<CheckoutReturnDecision> resolvePaymentReturn({
  required CheckoutOrderLookup lookup,
  required CheckoutAttemptIdentity attempt,
  Duration interval = kCheckoutOrderLookupInterval,
  Duration timeout = kCheckoutOrderLookupTimeout,
  bool correlationAvailable = kCheckoutTokenCorrelationAvailable,
  CheckoutOrderClock clock = DateTime.now,
  CheckoutOrderDelay delay = _defaultDelay,
  bool Function()? isCancelled,
}) async {
  final started = clock();
  var lookupFailed = false;
  while (true) {
    if (isCancelled?.call() == true) {
      return const CheckoutReturnUncertain();
    }
    try {
      final match = await lookup.findOrder(attempt);
      if (match != null) return CheckoutOrderFound(match);
    } on Object {
      lookupFailed = true;
    }
    final elapsed = clock().difference(started);
    if (elapsed >= timeout) return _settle(correlationAvailable, lookupFailed);
    final remaining = timeout - elapsed;
    final wait = remaining < interval ? remaining : interval;
    if (wait <= Duration.zero) {
      return _settle(correlationAvailable, lookupFailed);
    }
    await delay(wait);
  }
}

CheckoutReturnDecision _settle(bool correlationAvailable, bool lookupFailed) {
  if (lookupFailed || !correlationAvailable) {
    return const CheckoutReturnUncertain();
  }
  return const CheckoutOrderNotFound();
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
