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

/// Maps one `items[]` entry from `GET /v1/external-catalog`. Throws on a
/// record missing a field the wire schema guarantees is required
/// (`sourceScopedId`, `source`, `title`, `detailUrl`) — callers should treat
/// that as a schema-version mismatch, not silently drop the field.
CatalogItem catalogItemFromExternalJson(Map<String, dynamic> json) {
  final rawObservedAt = json['lastObservedAt'];

  return CatalogItem(
    sourceScopedId: json['sourceScopedId'] as String,
    source: _sourceTypeFromId(json['source'] as String),
    merchant: '${json['merchant'] ?? ''}',
    title: json['title'] as String,
    brand: '${json['brand'] ?? ''}',
    category: json['category'] as String?,
    imageUrl: json['imageUrl'] as String?,
    price: _priceFromJson(json['price']),
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
  );
}
