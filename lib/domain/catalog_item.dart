/// A source-independent product for feature presentation.
///
/// [Product] (`domain/product.dart`) stays a *raw Shopify entity* — see its
/// own doc comment. [CatalogItem] is the type the mixed feed, the home
/// screen and recommendations actually work with, whether the item came from
/// Monetta's own Shopify catalog or from an owner-procurement source (the US
/// Coach / Michael Kors / GUESS / Steve Madden catalog monitor — see
/// `lib/data/external_catalog/README.md`). Keeping the two types distinct
/// means a Shopify product and a scraped listing can never be silently
/// confused with each other: there is no `CatalogItem.fromShopify()` that
/// pretends an external record is a Shopify product, only explicit mappers
/// (`data/shopify/catalog_item_mapper.dart`,
/// `data/external_catalog/external_catalog_mapper.dart`) that both produce
/// this one shape.
///
/// Pure Dart — no Flutter, no codegen. Same rationale as `domain/product.dart`.
library;

enum CatalogSourceType {
  monettaShopify,
  coachUs,
  michaelKorsUs,
  guessUs,
  steveMaddenUs,
}

enum Currency { mxn, usd }

enum CatalogAvailability { inStock, outOfStock, unknown }

enum MarketRestriction { mexico, unitedStates }

/// How an item can be acted on. Owner-procurement items are sourced
/// candidates: the owner can inspect the merchant page and purchase manually,
/// but they never enter Monetta's cart, Shopify checkout, or WhatsApp flow.
/// See `features/home/external_catalog_section.dart`.
enum PurchaseMode {
  monettaCheckout,
  externalResearch,
  ownerProcurement,
}

class Money {
  const Money({required this.amount, required this.currency});

  final double amount;
  final Currency currency;

  String get currencyCode => currency == Currency.mxn ? 'MXN' : 'USD';
}

class CatalogItem {
  const CatalogItem({
    required this.sourceScopedId,
    required this.source,
    required this.merchant,
    required this.title,
    required this.brand,
    required this.category,
    required this.imageUrl,
    required this.price,
    required this.availability,
    required this.detailUrl,
    required this.marketRestriction,
    required this.lastObservedAt,
    required this.purchaseMode,
    this.shopifyProductId,
  });

  /// Unique within [source]; never assumed unique across sources. Monetta
  /// items are scoped as `monetta:<shopify id>`, external items as
  /// `<source>:<external id>` (matching the backend's `sourceScopedId`).
  final String sourceScopedId;
  final CatalogSourceType source;
  final String merchant;
  final String title;
  final String brand;
  final String? category;
  final String? imageUrl;

  /// Null when the price is genuinely unknown — a missing or malformed price
  /// from an external source, most commonly. Never coerced to a zero amount:
  /// `$0 USD` reads as "free," which is never true here. Monetta items always
  /// have a non-null price (`data/shopify/catalog_item_mapper.dart`); see
  /// `app/theme.dart#formatCatalogMoney` for how the UI renders the null case.
  final Money? price;
  final CatalogAvailability availability;

  /// For a Monetta item this is the in-app product route; for an external
  /// item this is the merchant's own page, which the CTA opens outside the
  /// app — see [isExternal].
  final String detailUrl;
  final MarketRestriction marketRestriction;
  final DateTime lastObservedAt;
  final PurchaseMode purchaseMode;

  /// Set only for [PurchaseMode.monettaCheckout] items. Lets the UI route
  /// back into the existing Shopify-backed product screen without the
  /// mixed-feed layer needing to know anything about Shopify.
  final String? shopifyProductId;

  /// True for any item that must not enter Monetta's checkout path.
  bool get isExternal => purchaseMode != PurchaseMode.monettaCheckout;

  bool get isOwnerProcurement => purchaseMode == PurchaseMode.ownerProcurement;

  /// Normalized `brand::title`, used *only* for exact-match dedupe against
  /// Monetta's own catalog (see `app/mixed_feed.dart`). Never used for
  /// fuzzy matching or cross-source ranking — the spec is explicit that
  /// fuzzy matching without SKU/UPC evidence is not allowed.
  String get dedupeKey => '${_normalize(brand)}::${_normalize(title)}';

  static String _normalize(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// HTTPS hosts that are actually allowed to serve an external item's detail
/// page, keyed by declared source. The backend already restricts crawled
/// URLs to these shapes (`services/catalog_monitor/src/adapters/*.ts`), but
/// the app must never trust a URL it is about to hand to the OS without
/// re-checking it here — a compromised or buggy backend response must not be
/// able to make the app open an arbitrary link under
/// `LaunchMode.externalApplication`.
const Map<CatalogSourceType, Set<String>> kAllowedExternalDetailHosts = {
  CatalogSourceType.coachUs: {'coach.com', 'www.coach.com'},
  CatalogSourceType.michaelKorsUs: {'michaelkors.com', 'www.michaelkors.com'},
  CatalogSourceType.guessUs: {'guess.com', 'www.guess.com'},
  CatalogSourceType.steveMaddenUs: {
    'stevemadden.com',
    'www.stevemadden.com',
  },
};

/// True only for an external item whose [CatalogItem.detailUrl] is an HTTPS
/// URL on a host that actually belongs to its declared [CatalogItem.source].
/// Always false for a Monetta item — that path never goes through this
/// check, see [PurchaseMode].
bool isValidExternalDetailUrl(CatalogItem item) {
  final allowedHosts = kAllowedExternalDetailHosts[item.source];
  if (allowedHosts == null) return false;
  final uri = Uri.tryParse(item.detailUrl);
  if (uri == null) return false;
  if (uri.scheme != 'https') return false;
  return allowedHosts.contains(uri.host.toLowerCase());
}

/// A human-readable `host/path` rendering of [CatalogItem.detailUrl] — the
/// merchant page an external item's data was pulled from — meant to be shown
/// directly in an item's description, not just hidden behind a CTA. Falls
/// back to the raw string for a URL that fails to parse rather than throwing;
/// callers still gate the actual open action through
/// [isValidExternalDetailUrl].
String sourceLinkLabel(CatalogItem item) {
  final uri = Uri.tryParse(item.detailUrl);
  if (uri == null || uri.host.isEmpty) return item.detailUrl;
  return '${uri.host}${uri.path}';
}
