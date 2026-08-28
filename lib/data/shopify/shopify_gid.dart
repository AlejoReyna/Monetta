/// Canonical Shopify resource identities used throughout the Monetta domain.
library;

final RegExp _numericId = RegExp(r'^\d+$');

String shopifyProductGid(Object? value) => _canonicalGid(value, 'Product');

String shopifyVariantGid(Object? value) =>
    _canonicalGid(value, 'ProductVariant');

String _canonicalGid(Object? value, String resource) {
  if (value == null) throw FormatException('Missing Shopify $resource id');
  final raw = value.toString().trim();
  final prefix = 'gid://shopify/$resource/';
  if (raw.startsWith(prefix) &&
      _numericId.hasMatch(raw.substring(prefix.length))) {
    return raw;
  }
  if (_numericId.hasMatch(raw)) return '$prefix$raw';
  throw FormatException('Invalid Shopify $resource id');
}
