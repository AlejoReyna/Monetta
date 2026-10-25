/// Flutter-free checkout presentation port implemented by the native bridges.
library;

/// A URL that has already passed the checkout allowlist policy.
///
/// Its value is available only for the native bridge. Stringification always
/// redacts it so accidental interpolation cannot disclose a checkout session.
final class ValidatedCheckoutUrl {
  const ValidatedCheckoutUrl._(Uri value) : _value = value;

  final Uri _value;

  Uri revealForNativeBridge() => _value;

  @override
  String toString() => 'ValidatedCheckoutUrl(<redacted>)';
}

/// Fails closed before a sensitive checkout URL crosses into native code.
final class CheckoutUrlPolicy {
  CheckoutUrlPolicy({required Iterable<String> allowedHosts})
      : _allowedHosts = Set.unmodifiable(
          allowedHosts.map(_normalizeHost).where((host) => host.isNotEmpty),
        ) {
    if (_allowedHosts.isEmpty) {
      throw const CheckoutUrlPolicyException();
    }
  }

  factory CheckoutUrlPolicy.forShopDomain(String shopDomain) =>
      CheckoutUrlPolicy(allowedHosts: [shopDomain]);

  final Set<String> _allowedHosts;

  ValidatedCheckoutUrl validate(String rawValue) {
    if (rawValue.isEmpty ||
        rawValue.length > 4096 ||
        rawValue.contains('\\') ||
        _hasExplicitPort(rawValue) ||
        rawValue.contains(RegExp(r'[\s\x00]'))) {
      throw const CheckoutUrlPolicyException();
    }
    final uri = Uri.tryParse(rawValue);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        _hasUserInfoMarker(rawValue) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasPort ||
        uri.path.isEmpty ||
        uri.path == '/' ||
        _hasUntrustedRedirect(uri) ||
        !_allowedHosts.contains(uri.host.toLowerCase())) {
      throw const CheckoutUrlPolicyException();
    }
    return ValidatedCheckoutUrl._(uri);
  }

  static String _normalizeHost(String value) {
    final candidate = value.trim().toLowerCase();
    if (candidate.isEmpty ||
        candidate.contains(RegExp(r'[/\\:@\s]')) ||
        candidate.startsWith('.') ||
        candidate.endsWith('.')) {
      return '';
    }
    final parsed = Uri.tryParse('https://$candidate');
    return parsed?.host == candidate ? candidate : '';
  }

  static bool _hasExplicitPort(String rawValue) {
    final authority = _authority(rawValue);
    if (authority == null) return false;
    return authority.split('@').last.contains(':');
  }

  static bool _hasUserInfoMarker(String rawValue) =>
      _authority(rawValue)?.contains('@') ?? false;

  static bool _hasUntrustedRedirect(Uri uri) {
    for (final value in uri.queryParameters.values) {
      final target = Uri.tryParse(value);
      if (target != null && target.hasAuthority) return true;
    }
    return false;
  }

  static String? _authority(String rawValue) {
    final schemeEnd = rawValue.indexOf('://');
    if (schemeEnd < 0) return null;
    final authorityStart = schemeEnd + 3;
    final authorityEnd = rawValue.indexOf(
      RegExp(r'[/\\?#]'),
      authorityStart,
    );
    return rawValue.substring(
      authorityStart,
      authorityEnd < 0 ? rawValue.length : authorityEnd,
    );
  }
}

final class CheckoutUrlPolicyException implements Exception {
  const CheckoutUrlPolicyException();

  @override
  String toString() => 'CheckoutUrlPolicyException(<redacted>)';
}

enum CheckoutFailureCode {
  cartExpired,
  cartCompleted,
  invalidCart,
  unavailable,
  configuration,
  unknown,
}

sealed class CheckoutResult {
  const CheckoutResult();
}

final class CheckoutCompleted extends CheckoutResult {
  const CheckoutCompleted();
}

final class CheckoutCancelled extends CheckoutResult {
  const CheckoutCancelled();
}

/// Shown when the online store's password page would replace checkout.
///
/// Shopify answers `https://{shop}/`, `/cart`, `/checkout`, and `/cart/c/…`
/// with a redirect to `/{shop}/password`. Opening `checkoutUrl` then shows
/// the store page. No charge was attempted.
const String kStorefrontPasswordCheckoutMessage =
    'La tienda está protegida con contraseña, así que Shopify muestra la '
    'página de la tienda en lugar del checkout. No se hizo ningún cargo y '
    'tu bolsa se conserva.';

/// Shown when the cart Shopify would hand to checkout has no merchandise.
///
/// An empty cart still has a `checkoutUrl`. Opening it sends the buyer to
/// the store home instead of a payable checkout.
const String kEmptyCartCheckoutMessage =
    'Shopify no abre el checkout de una bolsa vacía: esa dirección vuelve '
    'a la página de la tienda. No se hizo ningún cargo.';

final class CheckoutFailed extends CheckoutResult {
  const CheckoutFailed({
    required this.code,
    required this.userMessage,
    this.allowExternalBrowser = true,
  });

  final CheckoutFailureCode code;
  final String userMessage;

  /// False when the system browser would hit the same storefront redirect
  /// as the in-app sheet. The fallback must not be offered in that case.
  final bool allowExternalBrowser;
}

/// Only lifecycle state crosses this boundary. Order/customer/payment details,
/// cart tokens, web pixels and arbitrary clicked links remain native/Shopify.
abstract interface class CheckoutLauncher {
  Future<void> preload(ValidatedCheckoutUrl checkoutUrl);

  Future<CheckoutResult> present(ValidatedCheckoutUrl checkoutUrl);

  Future<void> invalidate();
}

/// Explicit browser fallback. Opening it never implies checkout completion.
abstract interface class ExternalCheckoutOpener {
  Future<bool> open(ValidatedCheckoutUrl checkoutUrl);
}
