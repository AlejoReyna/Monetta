/// Minimal Flutter platform channel for the official native Checkout Kit SDKs.
library;

import 'package:flutter/services.dart';

import '../data/shopify/cart/checkout_launcher.dart';

final class MethodChannelCheckoutLauncher implements CheckoutLauncher {
  MethodChannelCheckoutLauncher({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'mx.monetta.checkout_kit';

  final MethodChannel _channel;
  bool _presenting = false;

  @override
  Future<void> preload(ValidatedCheckoutUrl checkoutUrl) async {
    try {
      await _channel.invokeMethod<void>('preload', {
        'url': checkoutUrl.revealForNativeBridge().toString(),
      });
    } on PlatformException {
      throw const CheckoutBridgeException();
    } on MissingPluginException {
      throw const CheckoutBridgeException();
    }
  }

  @override
  Future<CheckoutResult> present(ValidatedCheckoutUrl checkoutUrl) async {
    if (_presenting) {
      return const CheckoutFailed(
        code: CheckoutFailureCode.unavailable,
        userMessage: 'Ya hay un checkout abierto.',
      );
    }
    _presenting = true;
    try {
      final raw = await _channel.invokeMethod<Object?>('present', {
        'url': checkoutUrl.revealForNativeBridge().toString(),
      });
      if (raw is! Map) return _safeFailure(CheckoutFailureCode.unknown);
      return switch (raw['status']) {
        'completed' => const CheckoutCompleted(),
        'cancelled' => const CheckoutCancelled(),
        'failed' => _safeFailure(_failureCode(raw['code'])),
        _ => _safeFailure(CheckoutFailureCode.unknown),
      };
    } on PlatformException {
      return _safeFailure(CheckoutFailureCode.unavailable);
    } on MissingPluginException {
      return _safeFailure(CheckoutFailureCode.configuration);
    } finally {
      _presenting = false;
    }
  }

  @override
  Future<void> invalidate() async {
    try {
      await _channel.invokeMethod<void>('invalidate');
    } on PlatformException {
      throw const CheckoutBridgeException();
    } on MissingPluginException {
      throw const CheckoutBridgeException();
    }
  }

  static CheckoutFailureCode _failureCode(Object? raw) => switch (raw) {
        'cart_expired' => CheckoutFailureCode.cartExpired,
        'cart_completed' => CheckoutFailureCode.cartCompleted,
        'invalid_cart' => CheckoutFailureCode.invalidCart,
        'unavailable' => CheckoutFailureCode.unavailable,
        'configuration' => CheckoutFailureCode.configuration,
        _ => CheckoutFailureCode.unknown,
      };

  static CheckoutFailed _safeFailure(CheckoutFailureCode code) =>
      CheckoutFailed(
        code: code,
        userMessage: switch (code) {
          CheckoutFailureCode.cartExpired =>
            'El checkout venció. Actualiza tu bolsa e inténtalo de nuevo.',
          CheckoutFailureCode.cartCompleted =>
            'Este checkout ya fue completado.',
          CheckoutFailureCode.invalidCart =>
            'Shopify no pudo verificar esta bolsa.',
          CheckoutFailureCode.configuration =>
            'El checkout no está disponible en esta configuración.',
          CheckoutFailureCode.unavailable ||
          CheckoutFailureCode.unknown =>
            'No fue posible abrir el checkout. Tu bolsa se conserva.',
        },
      );
}

final class CheckoutBridgeException implements Exception {
  const CheckoutBridgeException();

  @override
  String toString() => 'CheckoutBridgeException(<redacted>)';
}
