/// Shopify CDN helpers. Pure Dart — no Flutter.
///
/// Catalog snapshots ship full-resolution originals. Decoding those at
/// device pixel ratio inside a grid is how a slide goes blank on a phone.
library;

class MediaUrl {
  const MediaUrl._();

  static const int heroWidth = 1200;
  static const int cardWidth = 800;
  static const int thumbWidth = 400;

  /// Rewrites a Shopify CDN URL so the edge returns a width-capped JPEG.
  /// Non-Shopify URLs pass through unchanged.
  static String sized(String url, {required int width}) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    if (!_isShopifyHost(uri.host)) return url;
    final capped = width.clamp(80, 1800);
    final params = Map<String, String>.from(uri.queryParameters);
    params['width'] = '$capped';
    return uri.replace(queryParameters: params).toString();
  }

  static bool isHttps(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.isScheme('https');
  }

  static bool _isShopifyHost(String host) {
    final lower = host.toLowerCase();
    return lower.contains('shopify') ||
        lower.contains('shopifycdn') ||
        lower.endsWith('monetta.mx');
  }
}
