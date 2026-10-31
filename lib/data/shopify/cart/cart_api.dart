/// Typed boundary for Shopify Storefront Cart API operations.
///
/// This file deliberately contains no transport or GraphQL implementation.
/// Phase 1 implements this port against Storefront API `2026-07`.
library;

import '../../../domain/cart.dart';

/// A Shopify cart ID is a sensitive bearer-like value because it can contain
/// a secret query component. It must only be revealed at the Storefront API
/// boundary and must never be interpolated into logs or errors.
final class SensitiveCartId {
  SensitiveCartId(String value) : _value = value.trim() {
    if (_value.isEmpty) {
      throw const FormatException('Missing Shopify cart identifier');
    }
  }

  final String _value;

  String revealForStorefrontRequest() => _value;

  @override
  bool operator ==(Object other) =>
      other is SensitiveCartId && other._value == _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => 'SensitiveCartId(<redacted>)';
}

/// Short-lived customer credential used only while updating buyer identity.
/// The concrete provider remains responsible for refresh and expiry.
final class SensitiveCustomerAccessToken {
  SensitiveCustomerAccessToken(String value) : _value = value.trim() {
    if (_value.isEmpty) {
      throw const FormatException('Missing customer credential');
    }
  }

  final String _value;

  String revealForStorefrontRequest() => _value;

  @override
  String toString() => 'SensitiveCustomerAccessToken(<redacted>)';
}

sealed class CartBuyerIdentity {
  const CartBuyerIdentity({this.email, this.phone, this.countryCode = 'MX'});

  final String? email;
  final String? phone;
  final String countryCode;

  bool get isAuthenticated;

  @override
  String toString() =>
      'CartBuyerIdentity(authenticated: $isAuthenticated, <redacted>)';
}

final class GuestCartBuyerIdentity extends CartBuyerIdentity {
  const GuestCartBuyerIdentity({super.email, super.phone, super.countryCode});

  @override
  bool get isAuthenticated => false;
}

final class AuthenticatedCartBuyerIdentity extends CartBuyerIdentity {
  const AuthenticatedCartBuyerIdentity({
    required this.accessToken,
    super.email,
    super.phone,
    super.countryCode,
  });

  final SensitiveCustomerAccessToken accessToken;

  @override
  bool get isAuthenticated => true;
}

final class CartLineCreateInput {
  const CartLineCreateInput({
    required this.merchandiseId,
    required this.quantity,
    this.attributes = const {},
  });

  final String merchandiseId;
  final int quantity;
  final Map<String, String> attributes;
}

final class CartLineUpdateInput {
  const CartLineUpdateInput({required this.lineId, required this.quantity});

  final String lineId;
  final int quantity;
}

enum CartMutationIssueKind { userError, warning }

/// Safe, presentation-ready mutation feedback.
///
/// Raw GraphQL payloads, cart IDs, tokens and checkout URLs must be discarded
/// before constructing this value.
final class CartMutationIssue {
  CartMutationIssue({
    required this.kind,
    required this.message,
    this.code,
    List<String> field = const [],
  }) : field = List.unmodifiable(field);

  final CartMutationIssueKind kind;
  final String message;
  final String? code;
  final List<String> field;

  /// True when Shopify rejected the customer credential behind an
  /// authenticated buyer identity (expired, revoked or unknown token).
  ///
  /// Callers use this to offer login/recovery while keeping the local bag:
  /// the cart snapshot itself is still authoritative for lines and totals,
  /// only the sign-in association failed. Guest-first checkout stays
  /// available; this flag only decides whether to also surface login.
  bool get isAuthenticationIssue =>
      isAuthenticationSignal(code: code, field: field);

  /// Conservative predicate shared by the Storefront mapper and callers.
  ///
  /// Matches credential/account/session-shaped error codes plus the
  /// `customerAccessToken` input field. Line, discount and inventory codes
  /// never match; an unknown future code fails closed to false and keeps
  /// the generic message.
  static bool isAuthenticationSignal({
    String? code,
    List<String> field = const [],
  }) {
    final normalizedCode = (code ?? '').toUpperCase();
    if (normalizedCode.contains('CUSTOMER') ||
        normalizedCode.contains('TOKEN') ||
        normalizedCode.contains('AUTH') ||
        normalizedCode.contains('SESSION') ||
        normalizedCode.contains('LOGIN') ||
        normalizedCode.contains('EXPIRED') ||
        normalizedCode.contains('UNAUTHENTICATED') ||
        normalizedCode.contains('UNAUTHORIZED')) {
      return true;
    }
    return field.any(
      (part) => part.toLowerCase().contains('customeraccesstoken'),
    );
  }
}

final class CartMutationResult {
  CartMutationResult({
    required this.cart,
    List<CartMutationIssue> issues = const [],
  }) : issues = List.unmodifiable(issues);

  final Cart? cart;
  final List<CartMutationIssue> issues;

  bool get hasUserErrors =>
      issues.any((issue) => issue.kind == CartMutationIssueKind.userError);
}

enum CartApiFailureKind { unavailable, invalidResponse, unsupported }

/// Sanitized failure from the Cart API boundary.
final class CartApiException implements Exception {
  const CartApiException(this.kind, this.userMessage);

  final CartApiFailureKind kind;
  final String userMessage;

  @override
  String toString() => 'CartApiException(${kind.name})';
}

/// Remote operations required by the cart, discount and checkout phases.
///
/// Mutations return Shopify's cart snapshot plus both `userErrors` and
/// `warnings`; HTTP/GraphQL success alone is never treated as acceptance.
abstract interface class CartApi {
  Future<CartMutationResult> create({
    required List<CartLineCreateInput> lines,
    required Map<String, String> attributes,
    CartBuyerIdentity? buyerIdentity,
  });

  Future<Cart?> get(SensitiveCartId cartId);

  Future<CartMutationResult> addLines(
    SensitiveCartId cartId,
    List<CartLineCreateInput> lines,
  );

  Future<CartMutationResult> updateLines(
    SensitiveCartId cartId,
    List<CartLineUpdateInput> lines,
  );

  Future<CartMutationResult> removeLines(
    SensitiveCartId cartId,
    List<String> lineIds,
  );

  Future<CartMutationResult> updateBuyerIdentity(
    SensitiveCartId cartId,
    CartBuyerIdentity identity,
  );

  /// Replaces the complete code set. An empty list removes every code.
  Future<CartMutationResult> replaceDiscountCodes(
    SensitiveCartId cartId,
    List<String> discountCodes,
  );
}
