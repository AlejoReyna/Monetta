/// Detects an online-store password page without touching a checkout URL.
///
/// A password-protected dev store answers the public shop root with a
/// redirect to `/password`. The same gate sits in front of `/cart`,
/// `/checkout`, and Storefront cart permalinks (`/cart/c/…`), so Checkout
/// Kit would show the store page instead of checkout. The probe requests
/// only `https://{shop}/`. It never receives a cart id or `checkoutUrl`.
library;

import 'dart:async';

import 'package:http/http.dart' as http;

enum StorefrontPasswordGate {
  /// The shop root did not redirect to the password page.
  open,

  /// The shop root redirected to this shop's `/password` page.
  passwordProtected,

  /// The probe could not tell. Callers must still attempt checkout.
  unknown,
}

/// True only for an HTTPS redirect to `/password` on [shopHost].
///
/// A redirect to another host, to `/`, or to a lookalike path such as
/// `/password-reset` is not the storefront password page.
bool isStorefrontPasswordRedirect({
  required String shopHost,
  required int statusCode,
  String? location,
}) {
  if (!_isRedirect(statusCode)) return false;
  final host = shopHost.trim().toLowerCase();
  if (!_isProbeHost(host)) return false;
  final raw = location?.trim();
  if (raw == null || raw.isEmpty || raw.contains('\\')) return false;

  final Uri target;
  if (raw.startsWith('/')) {
    if (raw.startsWith('//')) return false;
    target = Uri.parse('https://$host$raw');
  } else {
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return false;
    target = parsed;
  }
  if (target.scheme != 'https' || target.host.toLowerCase() != host) {
    return false;
  }
  final path = target.path;
  return path == '/password' || path == '/password/';
}

abstract interface class StorefrontPasswordProbe {
  /// Checks the public shop root. [host] is a hostname, never a checkout URL.
  Future<StorefrontPasswordGate> checkHost(String host);
}

final class HttpStorefrontPasswordProbe implements StorefrontPasswordProbe {
  HttpStorefrontPasswordProbe({
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
  }) : _client = client;

  final http.Client? _client;
  final Duration timeout;

  @override
  Future<StorefrontPasswordGate> checkHost(String host) async {
    final normalized = host.trim().toLowerCase();
    if (!_isProbeHost(normalized)) return StorefrontPasswordGate.unknown;
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final request = http.Request('HEAD', Uri.https(normalized, '/'));
      request.followRedirects = false;
      final streamed = await client.send(request).timeout(timeout);
      await streamed.stream.drain<void>();
      if (isStorefrontPasswordRedirect(
        shopHost: normalized,
        statusCode: streamed.statusCode,
        location: streamed.headers['location'],
      )) {
        return StorefrontPasswordGate.passwordProtected;
      }
      return StorefrontPasswordGate.open;
    } on Object {
      return StorefrontPasswordGate.unknown;
    } finally {
      if (ownsClient) client.close();
    }
  }
}

bool _isRedirect(int statusCode) =>
    statusCode == 301 ||
    statusCode == 302 ||
    statusCode == 303 ||
    statusCode == 307 ||
    statusCode == 308;

bool _isProbeHost(String host) {
  if (host.isEmpty || host.length > 253) return false;
  if (!RegExp(r'^[a-z0-9.-]+$').hasMatch(host)) return false;
  if (host.startsWith('.') ||
      host.endsWith('.') ||
      host.startsWith('-') ||
      host.contains('..')) {
    return false;
  }
  return host.contains('.');
}
