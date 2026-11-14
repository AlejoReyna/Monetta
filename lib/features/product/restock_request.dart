/// G12 restock request types and submit contract (variant-scoped).
///
/// PDP/quick view wire an [onRestock] callback (A02) into [showRestockRequestSheet].
/// Transport stays injectable until A03 exposes variant-aware product alerts.
library;

import '../../domain/product.dart';

/// Outcome of a restock registration attempt.
enum RestockSubmitResult {
  created,
  alreadyRegistered,
  unavailable,
  error,
}

/// Payload sent to the configured restock channel.
class RestockRequestPayload {
  const RestockRequestPayload({
    required this.product,
    required this.variant,
    required this.email,
    required this.consentAccepted,
  });

  final Product product;
  final ProductVariant variant;

  /// Shopper email when the authorized channel requires it.
  final String email;
  final bool consentAccepted;
}

typedef RestockRequestSubmit = Future<RestockSubmitResult> Function(
  RestockRequestPayload payload,
);

/// PDP/quick-view hook surface (A02): open G12 for the selected exhausted variant.
typedef ProductRestockAction = void Function(
  Product product,
  ProductVariant variant,
);
