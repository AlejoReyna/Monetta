/// External-catalog JSON → [CatalogItem]. Kept separate from
/// `data/shopify/catalog_item_mapper.dart` on purpose — see that file's doc
/// comment and `domain/catalog_item.dart`: an external record must never be
/// mapped through the Shopify path or vice versa.
library;

import '../../domain/catalog_item.dart';

CatalogSourceType _sourceTypeFromId(String source) {
  switch (source) {
    case 'coach_us':
      return CatalogSourceType.coachUs;
    case 'michael_kors_us':
      return CatalogSourceType.michaelKorsUs;
    case 'guess_us':
      return CatalogSourceType.guessUs;
    case 'steve_madden_us':
      return CatalogSourceType.steveMaddenUs;
    case 'marc_jacobs_us':
      return CatalogSourceType.marcJacobsUs;
    case 'tory_burch_us':
      return CatalogSourceType.toryBurchUs;
    case 'kate_spade_us':
      return CatalogSourceType.kateSpadeUs;
    case 'guess_factory_us':
      return CatalogSourceType.guessFactoryUs;
    case 'gp_mcallen_perfumes':
      return CatalogSourceType.gpMcallenPerfumes;
    default:
      throw ArgumentError.value(
        source,
        'source',
        'Unknown external catalog source',
      );
  }
}

CatalogAvailability _availabilityFromJson(Object? raw) {
  switch (raw) {
    case 'inStock':
      return CatalogAvailability.inStock;
    case 'outOfStock':
      return CatalogAvailability.outOfStock;
    default:
      return CatalogAvailability.unknown;
  }
}

/// `null` — never a fabricated `$0` — whenever the price is absent, has a
/// non-numeric amount, or declares a currency this app does not know how to
/// treat as USD. This app validates the API's declared `currency` rather
/// than assuming every external price is USD: the wire schema happens to
/// hardcode `'USD'` today (`services/catalog_monitor/src/api/schema.ts`),
/// but a response claiming a different currency must never be silently
/// relabeled — that would compare/blend currencies exactly like blindly
/// forcing USD would.
Money? _priceFromJson(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final amount = raw['amount'];
  final currency = raw['currency'];
  if (amount is! num) return null;
  if (currency != 'USD') return null;
  return Money(amount: amount.toDouble(), currency: Currency.usd);
}

Money? _retailPriceFromJson(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final amount = raw['amount'];
  if (amount is! num || raw['currency'] != 'MXN') return null;
  return Money(amount: amount.toDouble(), currency: Currency.mxn);
}

CatalogVertical _verticalFromJson(Object? raw) {
  switch (raw) {
    case 'bags_wallets':
      return CatalogVertical.bagsWallets;
    case 'perfumes':
      return CatalogVertical.perfumes;
    default:
      return CatalogVertical.general;
  }
}

List<CatalogVariant> _variantsFromJson(Object? raw) {
  if (raw is! List<dynamic>) return const [];
  return raw.whereType<Map<String, dynamic>>().map((json) {
    final sourcePrice = _priceFromJson(json['price']);
    return CatalogVariant(
      variantId: '${json['variantId'] ?? ''}',
      sku: json['sku'] as String?,
      colorName: json['colorName'] as String?,
      colorCode: json['colorCode'] as String?,
      imageUrl: json['imageUrl'] as String?,
      price: _retailPriceFromJson(json['suggestedRetailPrice']) ?? sourcePrice,
      sourcePrice: sourcePrice,
      availability: _availabilityFromJson(json['availability']),
      detailUrl: '${json['detailUrl'] ?? ''}',
    );
  }).where((variant) {
    return variant.variantId.isNotEmpty && variant.detailUrl.isNotEmpty;
  }).toList(growable: false);
}

/// Maps one `items[]` entry from `GET /v1/external-catalog`. Throws on a
/// record missing a field the wire schema guarantees is required
/// (`sourceScopedId`, `source`, `title`, `detailUrl`) — callers should treat
/// that as a schema-version mismatch, not silently drop the field.
CatalogItem catalogItemFromExternalJson(Map<String, dynamic> json) {
  final rawObservedAt = json['lastObservedAt'];
  final sourcePrice = _priceFromJson(json['price']);
  final commission = json['commission'];
  final commissionRate =
      commission is Map<String, dynamic> && commission['rate'] is num
          ? (commission['rate'] as num).toDouble()
          : null;
  final commissionRule =
      commission is Map<String, dynamic> && commission['rule'] is String
          ? commission['rule'] as String
          : null;

  return CatalogItem(
    sourceScopedId: json['sourceScopedId'] as String,
    source: _sourceTypeFromId(json['source'] as String),
    merchant: '${json['merchant'] ?? ''}',
    title: json['title'] as String,
    brand: '${json['brand'] ?? ''}',
    category: json['category'] as String?,
    imageUrl: json['imageUrl'] as String?,
    price: _retailPriceFromJson(json['suggestedRetailPrice']) ?? sourcePrice,
    sourcePrice: sourcePrice,
    commissionRate: commissionRate,
    commissionRule: commissionRule,
    vertical: _verticalFromJson(json['vertical']),
    availability: _availabilityFromJson(json['availability']),
    detailUrl: json['detailUrl'] as String,
    marketRestriction: MarketRestriction.unitedStates,
    lastObservedAt: rawObservedAt is String
        ? DateTime.tryParse(rawObservedAt) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    // No supplier-authorization record is required. These are owner-managed
    // procurement candidates: the owner verifies availability, shipping and
    // margin before buying and fulfilling them manually.
    purchaseMode: PurchaseMode.ownerProcurement,
    variants: _variantsFromJson(json['variants']),
  );
}
