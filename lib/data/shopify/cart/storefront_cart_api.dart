/// Storefront API `2026-07` implementation of [CartApi].
library;

import '../../../domain/cart.dart';
import '../mappers.dart';
import '../queries.dart';
import '../storefront_client.dart';
import 'cart_api.dart';
import 'cart_write_coordinator.dart';

final class StorefrontCartApi implements CartApi {
  const StorefrontCartApi(this._client);

  final StorefrontClient _client;

  @override
  Future<CartMutationResult> create({
    required List<CartLineCreateInput> lines,
    required Map<String, String> attributes,
    CartBuyerIdentity? buyerIdentity,
  }) =>
      _mutate(
        operation: CartWriteOperation.create,
        document: kCartCreateMutation,
        payloadKey: 'cartCreate',
        variables: {
          'input': {
            'lines': lines.map(_createLineInput).toList(growable: false),
            'attributes': attributes.entries
                .map((entry) => {'key': entry.key, 'value': entry.value})
                .toList(growable: false),
            if (buyerIdentity != null)
              'buyerIdentity': _buyerIdentityInput(buyerIdentity),
          },
        },
      );

  @override
  Future<Cart?> get(SensitiveCartId cartId) async {
    try {
      final data = await _client.query(
        kCartQuery,
        variables: {'cartId': cartId.revealForStorefrontRequest()},
      );
      final cart = data['cart'];
      if (cart == null) return null;
      if (cart is! Map<String, dynamic>) {
        throw const FormatException('Invalid cart payload');
      }
      return cartFromJson(cart);
    } on StorefrontException {
      throw const CartApiException(
        CartApiFailureKind.unavailable,
        'No fue posible consultar tu bolsa en este momento.',
      );
    } on FormatException {
      throw const CartApiException(
        CartApiFailureKind.invalidResponse,
        'Shopify devolvió una bolsa que no se pudo verificar.',
      );
    }
  }

  @override
  Future<CartMutationResult> addLines(
    SensitiveCartId cartId,
    List<CartLineCreateInput> lines,
  ) =>
      _mutate(
        operation: CartWriteOperation.addLines,
        document: kCartLinesAddMutation,
        payloadKey: 'cartLinesAdd',
        variables: {
          'cartId': cartId.revealForStorefrontRequest(),
          'lines': lines.map(_createLineInput).toList(growable: false),
        },
      );

  @override
  Future<CartMutationResult> updateLines(
    SensitiveCartId cartId,
    List<CartLineUpdateInput> lines,
  ) =>
      _mutate(
        operation: CartWriteOperation.updateLines,
        document: kCartLinesUpdateMutation,
        payloadKey: 'cartLinesUpdate',
        variables: {
          'cartId': cartId.revealForStorefrontRequest(),
          'lines': lines
              .map(
                (line) => {
                  'id': line.lineId,
                  'quantity': line.quantity,
                },
              )
              .toList(growable: false),
        },
      );

  @override
  Future<CartMutationResult> removeLines(
    SensitiveCartId cartId,
    List<String> lineIds,
  ) =>
      _mutate(
        operation: CartWriteOperation.removeLines,
        document: kCartLinesRemoveMutation,
        payloadKey: 'cartLinesRemove',
        variables: {
          'cartId': cartId.revealForStorefrontRequest(),
          'lineIds': List<String>.unmodifiable(lineIds),
        },
      );

  @override
  Future<CartMutationResult> updateBuyerIdentity(
    SensitiveCartId cartId,
    CartBuyerIdentity identity,
  ) =>
      _mutate(
        operation: CartWriteOperation.updateBuyerIdentity,
        document: kCartBuyerIdentityUpdateMutation,
        payloadKey: 'cartBuyerIdentityUpdate',
        variables: {
          'cartId': cartId.revealForStorefrontRequest(),
          'buyerIdentity': _buyerIdentityInput(identity),
        },
      );

  @override
  Future<CartMutationResult> replaceDiscountCodes(
    SensitiveCartId cartId,
    List<String> discountCodes,
  ) =>
      _mutate(
        operation: CartWriteOperation.replaceDiscountCodes,
        document: kCartDiscountCodesUpdateMutation,
        payloadKey: 'cartDiscountCodesUpdate',
        variables: {
          'cartId': cartId.revealForStorefrontRequest(),
          'discountCodes': List<String>.unmodifiable(discountCodes),
        },
      );

  Future<CartMutationResult> _mutate({
    required CartWriteOperation operation,
    required String document,
    required String payloadKey,
    required Map<String, dynamic> variables,
  }) async {
    try {
      final data = await _client.mutate(document, variables: variables);
      final payload = data[payloadKey];
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Invalid cart mutation payload');
      }
      final cartJson = payload['cart'];
      return CartMutationResult(
        cart: cartJson is Map<String, dynamic> ? cartFromJson(cartJson) : null,
        issues: _issuesFromPayload(payload),
      );
    } on StorefrontException catch (error) {
      if (error.isAmbiguous) {
        throw AmbiguousCartWriteException(operation);
      }
      throw const CartApiException(
        CartApiFailureKind.unavailable,
        'No fue posible actualizar tu bolsa en este momento.',
      );
    } on FormatException {
      throw const CartApiException(
        CartApiFailureKind.invalidResponse,
        'Shopify devolvió una bolsa que no se pudo verificar.',
      );
    }
  }

  static Map<String, dynamic> _createLineInput(CartLineCreateInput line) => {
        'merchandiseId': line.merchandiseId,
        'quantity': line.quantity,
        if (line.attributes.isNotEmpty)
          'attributes': line.attributes.entries
              .map((entry) => {'key': entry.key, 'value': entry.value})
              .toList(growable: false),
      };

  static Map<String, dynamic> _buyerIdentityInput(CartBuyerIdentity identity) =>
      {
        'countryCode': identity.countryCode,
        if (identity.email != null) 'email': identity.email,
        if (identity.phone != null) 'phone': identity.phone,
        if (identity is AuthenticatedCartBuyerIdentity)
          'customerAccessToken':
              identity.accessToken.revealForStorefrontRequest(),
      };

  static List<CartMutationIssue> _issuesFromPayload(
    Map<String, dynamic> payload,
  ) =>
      [
        ..._issues(payload['userErrors'], CartMutationIssueKind.userError),
        ..._issues(payload['warnings'], CartMutationIssueKind.warning),
      ];

  static Iterable<CartMutationIssue> _issues(
    Object? raw,
    CartMutationIssueKind kind,
  ) sync* {
    if (raw is! List) return;
    for (final item in raw.whereType<Map<String, dynamic>>()) {
      final code = _safeCode(item['code']);
      final field = kind == CartMutationIssueKind.userError
          ? _safeField(item['field'])
          : const <String>[];
      yield CartMutationIssue(
        kind: kind,
        code: code,
        field: field,
        message: _localizedIssue(kind, code, field: field),
      );
    }
  }

  static String? _safeCode(Object? raw) {
    final value = raw?.toString().toUpperCase();
    if (value == null ||
        value.length > 64 ||
        !RegExp(r'^[A-Z0-9_]+$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  static List<String> _safeField(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .where(
          (part) =>
              part.length <= 64 &&
              RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(part),
        )
        .toList(growable: false);
  }

  static String _localizedIssue(
    CartMutationIssueKind kind,
    String? code, {
    List<String> field = const [],
  }) {
    // An expired/revoked Customer Account token must degrade to
    // guest/re-login, never to a lost bag: the repository keeps the cart
    // snapshot, and this message points at recovery. Raw Shopify detail is
    // discarded before constructing the issue, so no token can leak here.
    if (kind == CartMutationIssueKind.userError &&
        CartMutationIssue.isAuthenticationSignal(code: code, field: field)) {
      return 'Tu sesión venció. Inicia sesión de nuevo; tu bolsa se conserva.';
    }
    if (kind == CartMutationIssueKind.warning) {
      return switch (code) {
        'MERCHANDISE_OUT_OF_STOCK' => 'Una variante está agotada.',
        'MERCHANDISE_NOT_ENOUGH_STOCK' =>
          'Shopify ajustó la cantidad al inventario disponible.',
        'PRODUCT_UNAVAILABLE_IN_BUYER_LOCATION' =>
          'Una variante no está disponible para tu ubicación.',
        _ => 'Shopify ajustó una parte de tu bolsa.',
      };
    }
    return switch (code) {
      'INVALID_MERCHANDISE_LINE' ||
      'MERCHANDISE_NOT_APPLICABLE' =>
        'Una variante ya no está disponible.',
      'MAXIMUM_EXCEEDED' =>
        'La cantidad solicitada supera el máximo disponible.',
      'SERVICE_UNAVAILABLE' =>
        'Shopify no pudo actualizar esta bolsa temporalmente.',
      _ => 'Shopify no aceptó una parte de tu bolsa.',
    };
  }
}
