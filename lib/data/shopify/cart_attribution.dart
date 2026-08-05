/// Order attribution.
///
/// Pure Dart. Every cart the app creates is stamped with attributes that land
/// on the Shopify order and are queryable in Admin and Analytics.
///
/// This is not analytics garnish: it is the evidence base for the
/// revenue-share arrangement. A percentage of "app-attributed revenue" is
/// unenforceable unless both parties can independently count it, so these
/// attributes are a commercial requirement as much as a technical one.
library;

/// Where the tap that led to this cart came from.
enum RecoSource {
  /// Personalized feed from `reco/`.
  profile,

  /// Trending / cold-start feed.
  trending,

  /// Search results.
  search,

  /// Collection browse.
  collection,

  /// Shopify's own `productRecommendations` on the product page.
  related,

  /// Wishlist, or a back-in-stock notification.
  wishlist,

  /// Push notification deep link.
  push,

  /// Direct link, deep link, or unknown.
  direct;

  String get wireValue => name;
}

class CartAttribution {
  const CartAttribution({
    required this.platform,
    required this.deviceId,
    required this.appVersion,
    this.recoSource = RecoSource.direct,
    this.campaignId,
  });

  /// `ios` | `android`.
  final String platform;

  /// Anonymous, app-generated UUID. **Not** an advertising identifier and not
  /// tied to any personal data — it exists so a disputed order can be traced to
  /// an install, nothing more.
  final String deviceId;

  final String appVersion;
  final RecoSource recoSource;

  /// Set when the session began from a campaign push notification.
  final String? campaignId;

  /// Shopify `AttributeInput` list.
  ///
  /// Keys are prefixed with `_` so Shopify treats them as private: they stay
  /// out of the customer-facing order confirmation and the checkout summary,
  /// but remain visible in Admin and in the Orders export.
  List<Map<String, String>> toAttributeInputs() => <Map<String, String>>[
        {'key': '_channel', 'value': 'app'},
        {'key': '_platform', 'value': platform},
        {'key': '_device_id', 'value': deviceId},
        {'key': '_app_version', 'value': appVersion},
        {'key': '_rec_source', 'value': recoSource.wireValue},
        if (campaignId != null) {'key': '_campaign', 'value': campaignId!},
      ];

  CartAttribution copyWith({RecoSource? recoSource, String? campaignId}) =>
      CartAttribution(
        platform: platform,
        deviceId: deviceId,
        appVersion: appVersion,
        recoSource: recoSource ?? this.recoSource,
        campaignId: campaignId ?? this.campaignId,
      );
}

/// Builds the WhatsApp "apartado" hand-off.
///
/// A large share of this store's revenue never touches Shopify checkout: the
/// Mayoreo page sells layaway over WhatsApp — reserve now, pay within 20 days,
/// $400 MXN deposit retail / $800 MXN wholesale. Ignoring that flow would mean
/// building an app that fights how the business actually sells.
///
/// Because these orders are created by hand in Shopify, attribution needs a
/// human-transcribable code rather than a cart attribute.
class ApartadoRequest {
  const ApartadoRequest({
    required this.productTitle,
    required this.productHandle,
    required this.price,
    required this.attributionCode,
    this.isWholesale = false,
  });

  final String productTitle;
  final String productHandle;
  final double price;

  /// Short code the owner writes on the manual order, e.g. `MN-7K3Q`.
  final String attributionCode;

  final bool isWholesale;

  static const String whatsappNumber = '528261066868';

  int get depositMxn => isWholesale ? 800 : 400;

  /// Prefilled es-MX message. Deliberately states the deposit terms so the
  /// customer arrives already knowing them, which is what makes the
  /// conversation short.
  String get message => '''
¡Hola Monetta! Me interesa apartar este producto:

*$productTitle*
Precio: \$${price.toStringAsFixed(2)} MXN
https://monetta.mx/products/$productHandle

Entiendo que el anticipo es de \$$depositMxn MXN y que puedo liquidar en hasta 20 días.

Código: $attributionCode''';

  Uri get uri => Uri.https(
        'wa.me',
        '/$whatsappNumber',
        <String, String>{'text': message},
      );
}

/// Generates the short attribution code.
///
/// Deliberately excludes vowels (no accidental words), and the characters
/// `0/O/1/I` which get mistyped when the owner reads a code off a phone screen
/// and types it into Shopify.
class AttributionCodeGenerator {
  const AttributionCodeGenerator();

  static const String _alphabet = '23456789BCDFGHJKLMNPQRSTVWXYZ';

  /// [seed] should be a random int; injected so tests are deterministic.
  String generate(int seed) {
    var value = seed.abs();
    final buffer = StringBuffer('MN-');
    for (var i = 0; i < 4; i++) {
      buffer.write(_alphabet[value % _alphabet.length]);
      value = value ~/ _alphabet.length;
    }
    return buffer.toString();
  }
}
